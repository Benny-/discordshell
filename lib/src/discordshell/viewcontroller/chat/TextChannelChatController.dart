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
import '../../model/DiscordShellBot.dart';
import '../../events/OpenDMChannelRequestEvent.dart';
import './ChatController.dart';
import '../../model/UserTimer.dart';

class TextChannelChatController extends ChatController {
  final discord.TextChannel _channel;
  final HtmlElement _titleContainer;
  final StreamController<OpenDMChannelRequestEvent> _onOpenDMChannelRequestEventStreamController;
  final Stream<OpenDMChannelRequestEvent> onOpenDMChannelRequestEvent;

  final DivElement _profileBar;
  discord.Member _profile;
  bool _editMod = false;
  final TextAreaElement _textArea;
  final TemplateElement _userTemplate;
  final List<UserTimer> _typingUsers = new List<UserTimer>();
  final DivElement _usersList;
  final DivElement _typing;
  bool _typingBusy = false;
  Timer _timer;

  TextChannelChatController._internal (
      DiscordShellBot _ds,
      this._channel,
      this._titleContainer,
      DivElement view,
      this._onOpenDMChannelRequestEventStreamController,
      this.onOpenDMChannelRequestEvent,
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
              view.querySelector("template[name=message-attachment]")
        )
  {
    assert(_usersList != null);
    assert(_textArea != null);
    assert(_typing != null);
    assert(_userTemplate != null);
    assert(_profileBar != null);
          
    ImageElement titleIcon = new ImageElement( src: this.ds.bot.self.avatarURL(format: 'png'), width: 128, height: 128);
    titleIcon.className = "user-avatar-tab-header";
    SpanElement titleText = new SpanElement();
    titleText.text = _channel.name;

    this._titleContainer.append(titleIcon);
    this._titleContainer.appendText(' ');
    this._titleContainer.append(titleText);

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
    _timer = new Timer.periodic(oneSec, (Timer t) => typingListUpdate());

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
        DivElement msgelement = messages.querySelector("[title='" + message.message.id.id + "']");
        msgelement.parent.remove();
      }
    });

    this.ds.bot.onMessageUpdate.listen((message) {
      if (message.newMessage.channel.id == _channel.id) {
        DivElement msgElement = messages.querySelector("[title='" + message.oldMessage.id.id + "']");
        msgElement.innerHtml = markdownToHtml(message.newMessage.content);
        msgElement.title = message.newMessage.id.id;
        if (!this.nodeValidator.allowsElement(msgElement)) {
          msgElement.parent.style.backgroundColor = "red";
          msgElement.text =
              "<<Remote code execution protection has prevented this message from being displayed>>";
        }
      }
    });

    _profileBar.querySelector(".profile-name-tag").children[0].addEventListener('click', (e){
      if(!_profile.bot) {
        _profileBar.style.display = "none";
        _profile.dmChannel.then((k){
          OpenDMChannelRequestEvent e = new OpenDMChannelRequestEvent(this.ds, k);
          _onOpenDMChannelRequestEventStreamController.add(e);
        });
      }
    });

    this._titleContainer.addEventListener('click', (e){
      this._titleContainer.style.color = "";
      _textArea.focus();
    });

    this.ds.bot.onMessage.listen((discord.MessageEvent e) {
      assert(e.message.channel != null);
      if (e.message.channel == this._channel) {
        if (this.view.parent.style.display == "none")
          this._titleContainer.style.color = e.message.content.contains("<@"+_ds.bot.self.id.id+">") ? "Red" : "Orange";
        this.addMessage(e.message, false);
        _typingUsers.forEach((f) {
          if (f.id == e.message.author.id) {
            f.count = 0;
            return;
          }
        });
      } else {
        assert(this._channel == null ||
            (e.message.channel.id != this._channel.id));
      }
    });

    ButtonElement historyButton = this.view.querySelector(".more-messages");
    historyButton.addEventListener('click', (e) {
      final discord.Snowflake snowflake = new discord.Snowflake(messages.querySelector(".content").title);
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
          if (text!=editMsg.content)
            editMsg.edit(content: text);
          _editMod = false;
        }else{
          _channel.send(content: text);
          messages.scrollTo(0,messages.scrollHeight);
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
          assert(member != null);
          assert(e.member != null);
          if (member.id == e.member.id) {
            member.status = e.member.status;
          }
        });
      }
      if (_channel == null) {
        return;
      }
      if (e.member.guild == _channel.guild) {
        HtmlElement avatar = _usersList.querySelector("[title='" + e.member.id.id + "']");
        ImageElement picture = avatar.parent.querySelector("img");
        if (e.member.status == discord.MemberStatus.from(null)) {
          avatar.className = "avatar discord-status-offline";
        } else {
          avatar.className = "avatar discord-status-" + e.member.status.toString();
        }
      }
    });

    _channel.getMessages().then((messages) {
      for(DivElement msg in this.messages.querySelectorAll(".message"))
      {
        msg.remove();
      }

      for (final user in _channel.guild.members.values) //put users into list
      {
        this.addUser(user); //add users from object list to display list
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

  factory TextChannelChatController(
      DiscordShellBot ds,
      discord.TextChannel channel,
      HtmlElement _titleContainer,
      HtmlElement _contentContainer,
      TemplateElement chatControllerTemplate,
      nodeValidator) {
    DocumentFragment fragment = document.importNode(chatControllerTemplate.content, true);
    DivElement view = fragment.querySelector('div.chat-pane');
    _contentContainer.append(fragment);
    StreamController<OpenDMChannelRequestEvent> streamController = new StreamController<OpenDMChannelRequestEvent>.broadcast();
    Stream<OpenDMChannelRequestEvent> stream = streamController.stream;

    return new TextChannelChatController._internal(
      ds,
      channel,
      _titleContainer,
      view,
      streamController,
      stream,
      nodeValidator
    );
  }

  addUser(discord.Member user) {
    DocumentFragment userFragment = document.importNode(_userTemplate.content, true);
    DivElement userItem = userFragment.querySelector(".user-item");
    ImageElement avatar = userFragment.querySelector("img.avatar");
    HtmlElement username = userFragment.querySelector(".user-list-name");
    if (user.avatar == null) {
      avatar.src = "images/iconless.png";
    } else {
      // TODO: Request webp if user agent supports it.
      avatar.src = user.avatarURL(format: 'png', size: 128);
    }
    avatar.title = user.id.id;
    username.text = user.nickname==null ? user.username : user.nickname;
    username.title = user.username;
    if (user.status == discord.MemberStatus.from(null)) {
      avatar.className = "avatar discord-status-offline";
    } else {
      avatar.className = "avatar discord-status-" + user.status.toString();
    }

    _usersList.append(userFragment);
    userItem.addEventListener('click', (e) {
      _profileBar.style.display = "";
      _profile = user;
      if (_profile.bot){
        _profileBar.querySelector(".profile-name-tag").children[0].style.display="none";
      }else {
        _profileBar.querySelector(".profile-name-tag").children[0].style.display="";
      }
      ImageElement profileImg = _profileBar.querySelector(".profile-icon");
      DivElement rolesList = _profileBar.querySelector(".profile-roles");
      AnchorElement anchor = profileImg.parent;
      profileImg.src = user.avatar == null ? "images/iconless.png" : user.avatarURL(format: 'png', size: 128);
      anchor.href = user.avatar == null ? "images/iconless.png" : user.avatarURL(format: 'png',size: 1024);
      _profileBar.querySelector(".profile-name").innerHtml = user.username;
      _profileBar.querySelector(".discriminator").innerHtml = "#"+user.discriminator;
      _profileBar.querySelectorAll(".profile-right")[0].innerHtml = user.nickname == null ? user.username : user.nickname;
      String ucreate = user.createdAt.toLocal().toString();
      _profileBar.querySelectorAll(".profile-right")[1].innerHtml = ucreate.substring(0,ucreate.indexOf("."));
      String ujoined = user.joinedAt.toLocal().toString();
      _profileBar.querySelectorAll(".profile-right")[2].innerHtml = ujoined.substring(0,ujoined.indexOf("."));
      //_profileBar.querySelectorAll(".profile-right")[3].innerHtml = user.game==null ? "" : user.game.name;
      // TODO: Set game information
      _profileBar.querySelectorAll(".profile-right")[4].innerHtml = user.id.id;
      while (rolesList.hasChildNodes()) {
        rolesList.firstChild.remove();
      }
      user.roles.forEach((role){
        ParagraphElement roleFragment = new ParagraphElement();
        roleFragment.className = "profile-role";
        roleFragment.innerHtml = role.name;
        roleFragment.style.color = role.color==null ? "#99aab5" : role.color.toString();
        roleFragment.style.borderColor = role.color==null ? "#99aab5" : role.color.toString();
        rolesList.append(roleFragment);
      });
      _profileBar.style.top = (userItem.getBoundingClientRect().topLeft.y-_profileBar.clientHeight/10+_profileBar.clientHeight)>document.documentElement.clientHeight ? (document.documentElement.clientHeight-_profileBar.clientHeight-10).toString()+"px" : (userItem.getBoundingClientRect().topLeft.y-_profileBar.clientHeight/10).toString()+"px";
      _profileBar.style.left = (userItem.getBoundingClientRect().topLeft.x-_profileBar.clientWidth-10).toString()+"px";
    });
  }

  Future<Null> destroy() async {
    this._timer.cancel();
    await this._onOpenDMChannelRequestEventStreamController.close();
    return await super.destroy();
  }
}
