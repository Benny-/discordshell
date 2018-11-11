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
import '../emoji/EmojiSelectorController.dart';
import '../../model/UserTimer.dart';
import '../message/MessageController.dart';

abstract class MessageChannelController {
  final DiscordShellBot _ds;
  final NodeValidator _nodeValidator;
  final HtmlElement _titleContainer;

  final DivElement _view;
  final DivElement _messages;
  DivElement _profileBar;
  discord.Message _editMsg;
  final DivElement _editBar;
  bool _editMod = false;
  final TemplateElement _messageTemplate;
  final TemplateElement _attachmentTemplate;
  final EmojiSelectorController _emojiSelectorController;
  final TextAreaElement _textArea;
  final List<UserTimer> _typingUsers = new List<UserTimer>();
  final DivElement _typing;
  bool _typingBusy = false;
  Timer _timer;
  StreamSubscription<discord.TypingEvent> _typingSubscription;
  StreamSubscription<discord.MessageEvent> _messageSubscription;
  StreamSubscription<discord.MessageUpdateEvent> _messageUpdateSubscription;
  StreamSubscription<discord.MessageDeleteEvent> _messageDeleteSubscription;

  MessageChannelController(this._ds,
                this._nodeValidator,
                this._titleContainer,
                this._view,
                this._messages,
                this._textArea,
                this._typing,
                this._profileBar,
                this._editBar,
                this._messageTemplate,
                this._attachmentTemplate):
        this._emojiSelectorController = new EmojiSelectorController(_ds, _view.querySelector('.emojis-selector')){
    assert(_view != null);
    assert(_editBar != null);
    assert(_messageTemplate != null);
    assert(_emojiSelectorController != null);

    ButtonElement chatButton = this._view.querySelector("button.chat");
    chatButton.addEventListener('click', (e) {
      String text = this._textArea.value;
      if (text.length > 0) {
        if (_editMod==true){
          if (text!=this._editMsg.content)
            this._editMsg.edit(content: text);
          _editMod = false;
        }else{
          channel.send(content: text);
          this._messages.scrollTo(0,this._messages.scrollHeight);
        }
      }
      this._textArea.value = '';
      chatButton.disabled = true;
      e.preventDefault();
    });

    chatButton.disabled = true;

    this._view.querySelector(".show-emojis").addEventListener("click", (e) async {
      if (this._emojiSelectorController.view.style.display == 'none') {
        this._emojiSelectorController.view.style.display = '';
      } else {
        this._emojiSelectorController.view.style.display = 'none';
      }
    });

    this._emojiSelectorController.onEmojiSelectionEvent.listen((e) {
      this._textArea.value += e.emoji.format();
      chatButton.disabled = false;
    });

    typingListUpdate() {
      _typing.text = "";
      List<UserTimer> removeList = new List<UserTimer>();
      _typingUsers.forEach((f) {
        if (f.count <= 0) {
          removeList.add(f);
        } else {
          f.count -= 1;
          _typing.text += f.name + ", ";
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
          _typing.text =
              _typing.text.substring(0, _typing.text.length - 2) +
                  " is typing...";
          break;
        case 2:
        case 3:
        case 4:
          _typing.text =
              _typing.text.substring(0, _typing.text.length - 2) +
                  " are typing...";
          break;
        default:
          _typing.text = "Several people are typing";
          break;
      }
    }
    this._editBar.style.display = 'none';
    this._profileBar.style.display = 'none';

    this._editBar.children[0].addEventListener('click', (e){
      this._editMsg.delete();
      this._editBar.style.display='none';
    });

    this._editBar.children[1].addEventListener('click', (e){
      _textArea.value = this._editMsg.content;
      _textArea.focus();
      _editMod = true;
      this._editBar.style.display='none';
    });

    const oneSec = const Duration(seconds: 1);
    _timer = new Timer.periodic(oneSec, (Timer t) => typingListUpdate());

    this._textArea.addEventListener('input', (e) {
      chatButton.disabled = this._textArea.value.length == 0;
      if (this._textArea.value.length != 0 && !this._typingBusy) {
        this._typingBusy = true;
        this.channel.startTyping().then((result) {
          this._typingBusy = false;
        });
      }
    });

    _typingSubscription = this._ds.bot.onTyping.listen((discord.TypingEvent typer) {
      assert(typer.channel != null);
      assert(typer.user != null);
      if (this.channel == null || typer.user.id == this._ds.bot.self.id ||
          typer.channel.id != this.channel.id) {
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

    this._titleContainer.addEventListener('click', (e){
      this._titleContainer.style.color = "";
      _textArea.focus();
    });

    _messageSubscription = this.ds.bot.onMessage.listen((discord.MessageEvent e) {
      assert(e.message != null);
      assert(e.message.channel != null);
      if (e.message.channel == this.channel) {
        if (this._view.parent.style.display == "none") {
          final String color = e.message.content.contains(
              "<@" + _ds.bot.self.id.id + ">") ? "Red" : "Orange";
          if (color == "Orange" && this._titleContainer.style.color == "Red") {
            // Ignore. Orange should not override Red.
          } else {
            this._titleContainer.style.color = color;
          }
        }
        this._addMessage(e.message, false);
        _typingUsers.forEach((f) {
          if (f.id == e.message.author.id) {
            f.count = 0;
            return;
          }
        });
      }
    });

    _messageUpdateSubscription = this.ds.bot.onMessageUpdate.listen((message) {
      if (message.newMessage.channel.id == channel.id) {
        DivElement msgElement = this._messages.querySelector("[title='" + message.oldMessage.id.id + "']");
        msgElement.innerHtml = markdownToHtml(message.newMessage.content);
        msgElement.title = message.newMessage.id.id;
        if (!this._nodeValidator.allowsElement(msgElement)) {
          msgElement.parent.style.backgroundColor = "red";
          msgElement.text =
          "<<Remote code execution protection has prevented this message from being displayed>>";
        }
      }
    });

    _messageDeleteSubscription = this.ds.bot.onMessageDelete.listen((message) {
      if (message.message.channel.id == channel.id) {
        DivElement msgElement = this._messages.querySelector("[title='" + message.message.id.id + "']");
        msgElement.parent.remove();
      }
    });

    ButtonElement historyButton = this._view.querySelector(".more-messages");
    historyButton.addEventListener('click', (e) {
      final discord.Snowflake snowflake = new discord.Snowflake(this._messages.querySelector(".content").title);
      channel
          .getMessages(before: snowflake)
          .then((messages) {
        List<discord.Message> list = new List<discord.Message>();

        for (final msg in messages.values) {
          list.add(msg);
        }

        list.sort((a, b) {
          return a.id.compareTo(b.id);
        });

        list.reversed.forEach((msg) {
          this._addMessage(msg, true);
        });
      }).catchError((e) {
        print(e);
        throw e;
      });
    });

    channel.getMessages().then((messages) {
      for(DivElement msg in this._messages.querySelectorAll(".message")) {
        msg.remove();
      }

      List<discord.Message> list = new List<discord.Message>();

      for (final msg in messages.values) {
        list.add(msg);
      }

      list.sort((a, b) {
        return a.id.compareTo(b.id);
      });

      list.forEach((msg) {
        this._addMessage(msg, false);
      });
    });
  }

  DiscordShellBot get ds => this._ds;

  discord.MessageChannel get channel;

  HtmlElement get titleContainer => this._titleContainer;

  _addMessage(discord.Message msg, bool top){
    DocumentFragment msgFragment = document.importNode(_messageTemplate.content, true);
    DivElement view = msgFragment.querySelector("div.message");
    MessageController messageController = new MessageController(view);
    messageController.onMessageOptionsEvent.listen((e) {
      if(e.msg.author.id == _ds.bot.self.id) {
        _editBar.style.top = e.elm.parent.getBoundingClientRect().topRight.y.toString()+"px";
        _editBar.style.right = (e.elm.parent.getBoundingClientRect().topRight.x+70).toString()+"px";
        _editBar.style.display = "";
        _editMsg = msg;
        _editBar.focus();
      }
    });
    ImageElement avatar = messageController.render(_ds, msg, _nodeValidator, _attachmentTemplate);

    if (top) {
      _messages.insertBefore(msgFragment, _messages.querySelector(".message"));
    } else {
      ElementList check = _messages.querySelectorAll(".message");
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
    _timer.cancel();
    await _typingSubscription.cancel();
    await _messageSubscription.cancel();
    await _messageUpdateSubscription.cancel();
    await _messageDeleteSubscription.cancel();
    await this._emojiSelectorController.destroy();
    return null;
  }
}
