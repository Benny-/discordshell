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
import 'package:discord/discord.dart' as discord;
import 'package:discord/browser.dart' as discord;
import 'package:markdown/markdown.dart';
import '../model/DiscordShellBot.dart';
import './ChatController.dart';
import './UserTimer.dart';

class DMChatController extends ChatController {
  final discord.DMChannel _channel;
  final HtmlElement _titleContainer;
  final HtmlElement _view;
  final NodeValidator _nodeValidator;

  final DivElement _messages;
  final DivElement _editBar;
  DivElement _profileBar;
  discord.Message _editMsg;
  discord.User _profile;
  bool _editMod = false;
  final TextAreaElement _textArea;
  final TemplateElement _messageTemplate;
  final TemplateElement _userTemplate;
  final List<UserTimer> _typingUsers = new List<UserTimer>();
  final DivElement _usersList;
  final DivElement _typing;
  bool _typingBusy = false;

  DMChatController._internal(
      DiscordShellBot _ds,
      this._channel,
      this._titleContainer,
      this._view,
      this._nodeValidator)
      : _messages = _view.querySelector(".chat-messages"),
        _profileBar = _view.querySelector(".profile-bar"),
        _usersList = _view.querySelector(".users-list"),
        _textArea = _view.querySelector("textarea"),
        _typing = _view.querySelector(".typing"),
        _userTemplate = _view.querySelector("template[name=user-template]"),
        _messageTemplate = _view.querySelector("template[name=message-template]"),
        _editBar = _view.querySelector(".editbarbox"),
        super(_ds)
  {
    assert(_messages != null);
    assert(_usersList != null);
    assert(_textArea != null);
    assert(_typing != null);
    assert(_userTemplate != null);
    assert(_messageTemplate != null);
    assert(_editBar != null);
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
    _editBar.style.display = 'none';
    _profileBar.style.display = 'none';
    _editBar.children[0].addEventListener('click', (e){
      _editMsg.delete();
      _editBar.style.display='none';
    });
    _editBar.children[1].addEventListener('click', (e){
      _textArea.value = _editMsg.content;
      _textArea.focus();
      _editMod = true;
      _editBar.style.display='none';
    });
    const oneSec = const Duration(seconds: 1);
    new Timer.periodic(oneSec, (Timer t) => typingListUpdate());
    this.ds.bot.onTyping.listen((typer) {
      if (_channel == null ||
          typer.user.id == this.ds.bot.user.id ||
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
        DivElement msgElement = _messages.querySelector("[title='" + message.message.id + "']");
        msgElement.parent.remove();
      }
    });

    this.ds.bot.onMessageUpdate.listen((message) {
      if (message.newMessage.channel.id == _channel.id) {
        DivElement msgElement = _messages.querySelector("[title='" + message.oldMessage.id + "']");
        msgElement.innerHtml = markdownToHtml(message.newMessage.content);
        msgElement.title = message.newMessage.id;
        if (!this._nodeValidator.allowsElement(msgElement)) {
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
        if (this._view.parent.style.display == "none")
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
    _profileBar.querySelectorAll(".profile-right")[1].innerHtml = _profile.id;
    ButtonElement historyButton = _view.querySelector(".more-messages");
    historyButton.addEventListener('click', (e) {
      _channel
          .getMessages(before: _messages.querySelector(".content").title)
          .then((message) {
        List<discord.Message> list = new List<discord.Message>();

        for (final msg in message.values) {
          list.add(msg);
        }

        list.sort((a, b) {
          return a.timestamp.compareTo(b.timestamp);
        });

        list.reversed.forEach((msg) {
          this.addMessage(msg, true);
        });
      }).catchError((e) {
        print(e);
        throw e;
      });
    });

    ButtonElement chatButton = _view.querySelector("button.chat");
    chatButton.addEventListener('click', (e) {
      String text = this._textArea.value;
      if (text.length > 0) {
        if (_editMod==true){
          if (text!=_editMsg.content)
            _editMsg.edit(content: text);
          _editMod = false;
        }else{
          _channel.send(content: text);
          _messages.scrollTo(0,_messages.scrollHeight);
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
          if (member.id == e.newMember.id) {
            member.status = e.newMember.status;
          }
        });
      }
      if (_channel == null) {
        return;
      }
    });

    _channel.getMessages().then((messages) {
      for(DivElement msg in this._messages.querySelectorAll(".message"))
      {
        msg.remove();
      }


      List<discord.Message> list = new List<discord.Message>();

      for (final msg in messages.values)
      {
        list.add(msg);
      }

      list.sort((a, b) {
        return a.timestamp.compareTo(b.timestamp);
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

  addMessage(discord.Message msg, bool top){
    DocumentFragment msgFragment = document.importNode(_messageTemplate.content, true);
    ImageElement avatar = msgFragment.querySelector(".user-avatar");
    HtmlElement username = msgFragment.querySelector(".user-name");
    DivElement content = msgFragment.querySelector(".content");
    if (msg.author.id == this.ds.bot.user.id){
      username.className += " Hhover";
      username.addEventListener('click', (e) {
        _editBar.style.top = username.parent.getBoundingClientRect().topRight.y.toString()+"px";
        _editBar.style.right = (username.parent.getBoundingClientRect().topRight.x+70).toString()+"px";
        _editBar.style.display = "";
        _editMsg = msg;
        _editBar.focus();
      });
    }
    if (msg.author.avatar == null) {
      avatar.src = "images/iconless.png";
    } else {
      // TODO: Request webp if user agent supports it.
      avatar.src = msg.author.avatarURL(format: 'png', size: 128);
    }
    username.title = msg.author.id;
    username.text = msg.author.username;
    msg.content = msg.content.replaceAll("<@"+this.ds.bot.user.id+">", "@"+this.ds.bot.user.username);
    content.innerHtml = markdownToHtml(msg.content);
    content.title = msg.id;
    if (!this._nodeValidator.allowsElement(content)) {
      msgFragment.querySelector(".message").style.backgroundColor = "red";
      content.text =
      "<<Remote code execution protection has prevented this message from being displayed>>";
    }
    if (top) {
      _messages.insertBefore(msgFragment, _messages.querySelector(".message"));
    } else {
      var check = _messages.querySelectorAll(".message");
      if (check.length != 0) {
        ImageElement lastMessage = check[check.length - 1].querySelector(".user-avatar");
        if (lastMessage.src == avatar.src) {
          avatar.style.opacity = "0";
        }
      }
      _messages.append(msgFragment);
      if (_messages.scrollTop+_messages.clientHeight>_messages.scrollHeight-50)
        _messages.scrollTo(0,_messages.scrollHeight);
    }
  }

  Future<Null> destroy() async {
    return null;
  }
}