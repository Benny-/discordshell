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
import 'dart:js' as js;
import 'package:discord/discord.dart' as discord;
import 'package:discord/browser.dart' as discord;
import 'package:markdown/markdown.dart';
import '../model/DiscordShellBot.dart';
import '../model/OpenDMChannelRequestEvent.dart';


class UserTimer {
  String name;
  num count;
  String id;

  UserTimer(this.name, this.count, this.id) {
  }
}

class TextChannelChatController {
  final DiscordShellBot _ds;
  final discord.TextChannel _channel;
  final HtmlElement _titleContainer;
  final HtmlElement _view;
  final NodeValidator _nodeValidator;
  final StreamController<OpenDMChannelRequestEvent> _onOpenDMChannelRequestEventStreamController;
  final Stream<OpenDMChannelRequestEvent> onOpenDMChannelRequestEvent;

  final DivElement _messages;
  final DivElement _editbar;
  final DivElement _profilebar;
  discord.Message _editmsg;
  discord.Member _profile;
  bool editmod = false;
  final TextAreaElement _textArea;
  final TemplateElement _messageTemplate;
  final TemplateElement _userTemplate;
  final List<UserTimer> _typingUsers = new List<UserTimer>();
  final DivElement _usersList;
  final DivElement _typing;
  bool _typingBusy = false;

  TextChannelChatController._internal(
      this._ds,
      this._channel,
      this._titleContainer,
      this._view,
      this._onOpenDMChannelRequestEventStreamController,
      this.onOpenDMChannelRequestEvent,
      this._nodeValidator)
      : _messages = _view.querySelector(".chat-messages"),
        _profilebar = _view.querySelector(".profile-bar"),
        _usersList = _view.querySelector(".users-list"),
        _textArea = _view.querySelector("textarea"),
        _typing = _view.querySelector(".typing"),
        _userTemplate = _view.querySelector("template[name=user-template]"),
        _messageTemplate = _view.querySelector("template[name=message-template]"),
        _editbar = _view.querySelector(".editbarbox")
  {
    assert(_messages != null);
    assert(_usersList != null);
    assert(_textArea != null);
    assert(_typing != null);
    assert(_userTemplate != null);
    assert(_messageTemplate != null);
    assert(_editbar != null);
    assert(_profilebar != null);
          
    ImageElement titleIcon = new ImageElement( src: this._ds.bot.user.avatarURL(format: 'png'), width: 128, height: 128);
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
    _editbar.style.display = 'none';
    _profilebar.style.display = 'none';
    _editbar.children[0].addEventListener('click', (e){
      _editmsg.delete();
      _editbar.style.display='none';
    });
    _editbar.children[1].addEventListener('click', (e){
      _textArea.value = _editmsg.content;
      _textArea.focus();
      editmod = true;
      _editbar.style.display='none';
    });
    const oneSec = const Duration(seconds: 1);
    new Timer.periodic(oneSec, (Timer t) => typingListUpdate());
    this._ds.bot.onTyping.listen((typer) {
      //print(typer.user.username+" Typing..."+typer.channel.name); //6 seconds
      if (_channel == null ||
          typer.user.id == this._ds.bot.user.id ||
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

    this._ds.bot.onMessageDelete.listen((message) {
      if (message.message.channel.id == _channel.id) {
        DivElement msgelement = _messages.querySelector("[title='" + message.message.id + "']");
        msgelement.parent.remove();
      }
    });

    this._ds.bot.onMessageUpdate.listen((message) {
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
    _profilebar.querySelector(".profile-name-tag").children[0].addEventListener('click', (e){
      _profilebar.style.display = "none";
      _profile.getChannel().then((k){
        OpenDMChannelRequestEvent e = new OpenDMChannelRequestEvent(this._ds, k);
        _onOpenDMChannelRequestEventStreamController.add(e);
      });
    });
    this._titleContainer.addEventListener('click', (e){
      this._titleContainer.style.color = "";
      _textArea.focus();
    });
    this._ds.bot.onMessage.listen((discord.MessageEvent e) {
      assert(e.message.channel != null);
      if (e.message.channel == this._channel) {
        if (this._view.parent.style.display == "none")
          this._titleContainer.style.color = e.message.content.contains("<@"+_ds.bot.user.id+">") ? "Red" : "Orange";
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
      });
    });

    ButtonElement chatButton = _view.querySelector("button.chat");
    chatButton.addEventListener('click', (e) {
      String text = this._textArea.value;
      if (text.length > 0) {
        if (editmod==true){
          if (text!=_editmsg.content)
            _editmsg.edit(content: text);
          editmod = false;
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

    this._ds.bot.onPresenceUpdate.listen((discord.PresenceUpdateEvent e) {
      for (discord.Guild guild in this._ds.bot.guilds.values) {
        guild.members.values.forEach((member) {
          if (member.id == e.newMember.id) {
            member.status = e.newMember.status;
          }
        });
      }
      if (_channel == null) {
        return;
      }
      if (e.newMember.guild == _channel.guild) {
        HtmlElement avatar =
            _usersList.querySelector("[title='" + e.newMember.id + "']");
        ImageElement picture = avatar.parent.querySelector("img");
        picture.className = "avatar discord-status-" + e.newMember.status;
      }
    });

    _channel.getMessages().then((messages) {
      for(DivElement msg in this._messages.querySelectorAll(".message"))
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
        return a.timestamp.compareTo(b.timestamp);
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
    avatar.title = user.id;
    username.text = user.nickname==null ? user.username : user.nickname;
    username.title = user.username;
    if (user.status == null) {
      avatar.className = "avatar discord-status-offline";
    } else {
      avatar.className = "avatar discord-status-" + user.status;
    }

    _usersList.append(userFragment);
    userItem.addEventListener('click', (e) {
      _profilebar.style.display = "";
      _profile = user;
      ImageElement profileimg = _profilebar.querySelector(".profile-icon");
      DivElement roleslist = _profilebar.querySelector(".profile-roles");
      AnchorElement ancho = profileimg.parent;
      profileimg.src = user.avatar == null ? "images/iconless.png" : user.avatarURL(format: 'png', size: 128);
      ancho.href = user.avatar == null ? "images/iconless.png" : user.avatarURL(format: 'png',size: 1024);
      _profilebar.querySelector(".profile-name").innerHtml = user.username;
      _profilebar.querySelector(".discriminator").innerHtml = "#"+user.discriminator;
      _profilebar.querySelectorAll(".profile-right")[0].innerHtml = user.nickname == null ? user.username : user.nickname;
      String ucreate = user.createdAt.toLocal().toString();
      _profilebar.querySelectorAll(".profile-right")[1].innerHtml = ucreate.substring(0,ucreate.indexOf("."));
      String ujoined = user.joinedAt.toLocal().toString();
      _profilebar.querySelectorAll(".profile-right")[2].innerHtml = ujoined.substring(0,ujoined.indexOf("."));
      _profilebar.querySelectorAll(".profile-right")[3].innerHtml = user.game==null ? "" : user.game.name;
      _profilebar.querySelectorAll(".profile-right")[4].innerHtml = user.id;
      while (roleslist.hasChildNodes()) {
        roleslist.firstChild.remove();
      }
      user.roles.forEach((f){
        ParagraphElement rolefragment = new ParagraphElement();
        rolefragment.className = "profile-role";
        rolefragment.innerHtml = user.guild.roles[f].name;
        rolefragment.style.color = user.guild.roles[f].color==null ? "#99aab5" : "#"+user.guild.roles[f].color.toRadixString(16);
        rolefragment.style.borderColor = user.guild.roles[f].color==null ? "#99aab5" : "#"+user.guild.roles[f].color.toRadixString(16);
        roleslist.append(rolefragment);
      });
      _profilebar.style.top = (userItem.getBoundingClientRect().topLeft.y-_profilebar.clientHeight/10+_profilebar.clientHeight)>document.documentElement.clientHeight ? (document.documentElement.clientHeight-_profilebar.clientHeight-10).toString()+"px" : (userItem.getBoundingClientRect().topLeft.y-_profilebar.clientHeight/10).toString()+"px";
      _profilebar.style.left = (userItem.getBoundingClientRect().topLeft.x-_profilebar.clientWidth-10).toString()+"px";
    });
  }
  addMessage(discord.Message msg, bool top){
    DocumentFragment msgFragment = document.importNode(_messageTemplate.content, true);
    ImageElement avatar = msgFragment.querySelector(".user-avatar");
    HtmlElement username = msgFragment.querySelector(".user-name");
    DivElement content = msgFragment.querySelector(".content");
    if (msg.author.id == _ds.bot.user.id){
      username.className += " Hhover";
      username.addEventListener('click', (e) {
        _editbar.style.top = username.parent.getBoundingClientRect().topRight.y.toString()+"px";
        _editbar.style.right = (username.parent.getBoundingClientRect().topRight.x+70).toString()+"px";
        _editbar.style.display = "";
        _editmsg = msg;
        _editbar.focus();
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
    if (msg.content.contains("<@"+_ds.bot.user.id+">")&&!top&&document.hidden)
      js.context.callMethod('notifyMe',[_channel.name,_channel.guild.iconURL(),msg.author.username+": "+msg.content.replaceAll("<@"+_ds.bot.user.id+">", "@"+_ds.bot.user.username),_titleContainer]);
    msg.content = msg.content.replaceAll("<@"+_ds.bot.user.id+">", "@"+_ds.bot.user.username);
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
