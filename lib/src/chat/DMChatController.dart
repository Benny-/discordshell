/*
BSD 3-Clause License

Copyright (c) 2018, Benny Jacobs
All rights reserved.

Redistribution and use in source and binary forms, with or without
modification, are permitted provided that the following conditions are met:

* Redistributions of source code must retain the above copyright notice, this
  list of conditions and the following disclaimer.

* Redistributions in binary form must reproduce the above copyright notice,
  this list of conditions and the following disclaimer in the documentation
  and/or other materials provided with the distribution.

* Neither the name of the copyright holder nor the names of its
  contributors may be used to endorse or promote products derived from
  this software without specific prior written permission.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE
FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
*/
/*
BSD 3-Clause License

Copyright (c) 2018, Benny Jacobs
All rights reserved.

Redistribution and use in source and binary forms, with or without
modification, are permitted provided that the following conditions are met:

* Redistributions of source code must retain the above copyright notice, this
  list of conditions and the following disclaimer.

* Redistributions in binary form must reproduce the above copyright notice,
  this list of conditions and the following disclaimer in the documentation
  and/or other materials provided with the distribution.

* Neither the name of the copyright holder nor the names of its
  contributors may be used to endorse or promote products derived from
  this software without specific prior written permission.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE
FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
*/
import 'dart:html';
import 'dart:async';
import 'package:nyxx/nyxx.dart' as discord;
import 'package:markdown/markdown.dart';
import '../model/DiscordShellBot.dart';
import './ChatController.dart';
import './UserTimer.dart';
import './EmojiSelectorController.dart';

class DMChatController extends ChatController {
  final discord.DMChannel _channel;
  final HtmlElement _titleContainer;

  DivElement _profileBar;
  discord.User _profile;
  bool _editMod = false;
  final TextAreaElement _textArea;
  final TemplateElement _userTemplate;
  final List<UserTimer> _typingUsers = new List<UserTimer>();
  final DivElement _usersList;
  final DivElement _typing;
  bool _typingBusy = false;

  DMChatController._internal(
      DiscordShellBot _ds,
      this._channel,
      this._titleContainer,
      DivElement view,
      NodeValidator nodeValidator)
      : _profileBar = view.querySelector(".profile-bar"),
        _usersList = view.querySelector(".users-list"),
        _textArea = view.querySelector("textarea"),
        _typing = view.querySelector(".typing"),
        _userTemplate = view.querySelector("template[name=user-template]"),
        super(_ds,
              nodeValidator,
              view,
              view.querySelector(".chat-messages"),
              view.querySelector(".profile-bar"),
              view.querySelector(".editbarbox"),
              view.querySelector("template[name=message-template]"),
              view.querySelector("template[name=message-attachment]"),
              new EmojiSelectorController(_ds, view.querySelector('.emojis-selector'))
        )
  {
    assert(_usersList != null);
    assert(_textArea != null);
    assert(_typing != null);
    assert(_userTemplate != null);
    assert(_profileBar != null);

    this._titleContainer.text = _channel.recipient.username;

    typingListUpdate() {
      _typing.innerHtml = "";
      List<UserTimer> removeList = new List<UserTimer>();
      _typingUsers.forEach((f) {
        if (f.count <= 0) {
          removeList.add(f);
        } else {
          f.count -= 1;
          _typing.innerHtml += f.name + ", ";
        }
      });
      removeList.forEach((f) {
        _typingUsers.remove(f);
      });
      removeList.clear();
      switch (_typingUsers.length) {
        case 0:
          break;
        case 1:
          _typing.innerHtml =
              _typing.innerHtml.substring(0, _typing.innerHtml.length - 2) +
                  " is typing...";
          break;
        case 2:
        case 3:
        case 4:
          _typing.innerHtml =
              _typing.innerHtml.substring(0, _typing.innerHtml.length - 2) +
                  " are typing...";
          break;
        default:
          _typing.innerHtml = "Several people are typing";
          break;
      }
    }
    this.editBar.style.display = 'none';
    _profileBar.style.display = 'none';
    this.editBar.children[0].addEventListener('click', (e){
      this.editMsg.delete();
      this.editBar.style.display='none';
    });
    this.editBar.children[1].addEventListener('click', (e){
      _textArea.value = this.editMsg.content;
      _textArea.focus();
      _editMod = true;
      this.editBar.style.display='none';
    });
    const oneSec = const Duration(seconds: 1);
    new Timer.periodic(oneSec, (Timer t) => typingListUpdate());
    this.ds.bot.onTyping.listen((typer) {
      if (_channel == null ||
          typer.user.id == this.ds.bot.self.id ||
          typer.channel.id != _channel.id) {
        return;
      }
      UserTimer user = new UserTimer(typer.user.username, 8, typer.user.id);
      bool found = false;
      _typingUsers.forEach((userTimer) {
        if (userTimer.name == user.name) {
          userTimer.count = 8;
          found = true;
        }
      });
      if (!found) {
        _typingUsers.add(user);
      }
    });

    this.ds.bot.onMessageDelete.listen((message) {
      if (message.message.channel.id == _channel.id) {
        DivElement msgElement = this.messages.querySelector("[title='" + message.message.id.id + "']");
        msgElement.parent.remove();
      }
    });

    this.ds.bot.onMessageUpdate.listen((message) {
      if (message.newMessage.channel.id == _channel.id) {
        DivElement msgElement = this.messages.querySelector("[title='" + message.oldMessage.id.id + "']");
        msgElement.innerHtml = markdownToHtml(message.newMessage.content);
        msgElement.title = message.newMessage.id.id;
        if (!this.nodeValidator.allowsElement(msgElement)) {
          msgElement.parent.style.backgroundColor = "red";
          msgElement.text =
          "<<Remote code execution protection has prevented this message from being displayed>>";
        }
      }
    });
    this._titleContainer.addEventListener('click', (e){
      this._titleContainer.style.color = "";
      _textArea.focus();
    });
    this.ds.bot.onMessage.listen((discord.MessageEvent e) {
      assert(e.message.channel != null);
      if (e.message.channel.id == this._channel.id) {
        if (this.view.parent.style.display == "none")
          this._titleContainer.style.color = "Red";
        this.addMessage(e.message, false);
        _typingUsers.forEach((f) {
          if (f.id == e.message.author.id) {
            f.count = 0;
            return;
          }
        });
      }
    });
    _profileBar.querySelector(".profile-roles").remove();
    _profile = _channel.recipient;
    _usersList.innerHtml = _profileBar.outerHtml;
    _profileBar = _usersList.firstChild;
    ImageElement profileImg = _profileBar.querySelector(".profile-icon");
    AnchorElement anchor = profileImg.parent;
    profileImg.src = _profile.avatar == null ? "images/iconless.png" : _profile.avatarURL(format: 'png', size: 128);
    anchor.href = _profile.avatar == null ? "images/iconless.png" : _profile.avatarURL(format: 'png',size: 1024);
    _profileBar.querySelector(".profile-name-tag img").remove();
    _profileBar.querySelector(".profile-name").innerHtml = _profile.username;
    _profileBar.querySelector(".discriminator").innerHtml = "#"+_profile.discriminator;
    _profileBar.querySelector(".profile-info").remove();
    String ucreate = _profile.createdAt.toLocal().toString();
    ucreate = ucreate.substring(0,ucreate.indexOf("."));
    _profileBar.querySelectorAll(".profile-info")[1].remove();
    _profileBar.querySelectorAll(".profile-info")[1].remove();
    _profileBar.querySelector(".profile-info").style.borderTop = "2px solid grey";
    _profileBar.querySelector(".profile-right").innerHtml = ucreate;
    _profileBar.querySelectorAll(".profile-right")[1].innerHtml = _profile.id.id;
    ButtonElement historyButton = this.view.querySelector(".more-messages");
    historyButton.addEventListener('click', (e) {
      final discord.Snowflake snowflake = new discord.Snowflake(this.messages.querySelector(".content").title);
      _channel
          .getMessages(before: snowflake)
          .then((message) {
        List<discord.Message> list = new List<discord.Message>();

        for (final msg in message.values) {
          list.add(msg);
        }

        list.sort((a, b) {
          return a.id.compareTo(b.id);
        });

        list.reversed.forEach((msg) {
          this.addMessage(msg, true);
        });
      }).catchError((e) {
        print(e);
        throw e;
      });
    });

    ButtonElement chatButton = this.view.querySelector("button.chat");
    chatButton.addEventListener('click', (e) {
      String text = this._textArea.value;
      if (text.length > 0) {
        if (_editMod==true){
          if (text!=this.editMsg.content)
            this.editMsg.edit(content: text);
          _editMod = false;
        }else{
          _channel.send(content: text);
          this.messages.scrollTo(0,this.messages.scrollHeight);
        }
      }
      this._textArea.value = '';
      chatButton.disabled = true;
      e.preventDefault();
    });

    chatButton.disabled = true;
    this._textArea.addEventListener('input', (e) {
      chatButton.disabled = this._textArea.value.length == 0;
      if (this._textArea.value.length != 0 && !this._typingBusy) {
        this._typingBusy = true;
        this._channel.startTyping().then((result) {
          this._typingBusy = false;
        });
      }
    });

    this.ds.bot.onPresenceUpdate.listen((discord.PresenceUpdateEvent e) {
      for (discord.Guild guild in this.ds.bot.guilds.values) {
        guild.members.values.forEach((member) {
          if (member.id == e.member.id) {
            member.status = e.member.status;
          }
        });
      }
      if (_channel == null) {
        return;
      }
    });

    _channel.getMessages().then((messages) {
      for(DivElement msg in this.messages.querySelectorAll(".message"))
      {
        msg.remove();
      }

      List<discord.Message> list = new List<discord.Message>();

      for (final msg in messages.values)
      {
        list.add(msg);
      }

      list.sort((a, b) {
        return a.id.compareTo(b.id);
      });

      list.forEach((msg) {
        this.addMessage(msg, false);
      });
    });
  }

  factory DMChatController(
      DiscordShellBot ds,
      discord.DMChannel channel,
      HtmlElement _titleContainer,
      HtmlElement _contentContainer,
      TemplateElement chatControllerTemplate,
      nodeValidator) {
    DocumentFragment fragment = document.importNode(chatControllerTemplate.content, true);
    DivElement view = fragment.querySelector('div.chat-pane');
    _contentContainer.append(fragment);

    return new DMChatController._internal(
        ds,
        channel,
        _titleContainer,
        view,
        nodeValidator
    );
  }

  Future<Null> destroy() async {
    return await super.destroy();
  }
}