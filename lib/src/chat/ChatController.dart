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

abstract class ChatController {
  final DiscordShellBot _ds;
  final NodeValidator _nodeValidator;

  final DivElement _view;
  final DivElement _messages;
  DivElement _profileBar;
  discord.Message _editMsg;
  final DivElement _editBar;
  final TemplateElement _messageTemplate;

  ChatController(this._ds,
                this._nodeValidator,
                this._view,
                this._messages,
                this._profileBar,
                this._editBar,
                this._messageTemplate) {
    assert(_messageTemplate != null);
    assert(_editBar != null);

    this._view.querySelector(".show-emojis").addEventListener("click", (e) async {
      Map<String, discord.Emoji> map = await this.getEmojis();

      map.forEach((s, emoji) {
        print(emoji);
      });
    });
  }

  DiscordShellBot get ds {
    return _ds;
  }

  DivElement view() {
    return this._view;
  }

  DivElement messages() {
    return this._messages;
  }

  DivElement editBar() {
    return this._editBar;
  }

  NodeValidator nodeValidator() {
    return this._nodeValidator;
  }

  discord.Message editMsg() {
    return _editMsg;
  }

  discord.Message setEditMsg(discord.Message message) {
    return this._editMsg = message;
  }

  Future<Map<String, discord.Emoji>> getEmojis() async {
    Map<String, discord.Emoji> emojis;
    await this._ds.bot.guilds.forEach((id, guild) async {
      print("Fetching emojis for " + id);
      Map<String, discord.Emoji> map = await guild.getEmojis();
      print("Got emojis for " + id);
      map.forEach((str, emoji) {
        emojis[str] = emoji;
      });
      return null;
    });
    return emojis;
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
      content.text = "<<Remote code execution protection has prevented this message from being displayed>>";
    }

    msg.attachments.forEach((s, attachment) {
      /// XXX: A false assumption is here that all attachments are images.
      ImageElement image = new ImageElement(src: attachment.url, width: attachment.width, height: attachment.height);
      content.append(image);
    });

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
    return null;
  }
}
