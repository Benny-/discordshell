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
import 'package:markdown/markdown.dart';
import 'package:nyxx/nyxx.dart' as discord;
import '../../model/DiscordShellBot.dart';
import '../../events/MessageOptionsEvent.dart';

class MessageController {
  final DivElement _view;
  discord.Message _message;

  final StreamController<MessageOptionsEvent> _onMessageOptionsEventStreamController;
  final Stream<MessageOptionsEvent> onMessageOptionsEvent;

  MessageController._internal(this._view, this._onMessageOptionsEventStreamController, this.onMessageOptionsEvent) {

    HtmlElement username = _view.querySelector(".user-name");
    username.addEventListener('click', (e) {
      assert(e.target == username);
      this._onMessageOptionsEventStreamController.add(new MessageOptionsEvent(e.target, _message));
    });
  }

  factory MessageController(DivElement _view) {
    StreamController<MessageOptionsEvent> streamController = new StreamController<MessageOptionsEvent>.broadcast();
    Stream<MessageOptionsEvent> stream = streamController.stream;
    return new MessageController._internal(_view, streamController, stream);
  }

  discord.Message get message => this._message;

  ImageElement render(DiscordShellBot ds,
      discord.Message msg,
      NodeValidator nodeValidator,
      TemplateElement attachmentTemplate) {
    this._message = msg;
    ImageElement avatar = _view.querySelector(".user-avatar");
    HtmlElement username = _view.querySelector(".user-name");
    DivElement content = _view.querySelector(".content");
    if (msg.author.id == ds.bot.self.id){
      username.className += " Hhover"; // TODO: Make this function idempotent
    }
    if (msg.author.avatar == null) {
      avatar.src = "images/iconless.png";
    } else {
      // TODO: Request webp if user agent supports it.
      avatar.src = msg.author.avatarURL(format: 'png', size: 128);
    }
    username.title = msg.author.id.id;
    username.text = msg.author.username;
    content.innerHtml = markdownToHtml(msg.content.replaceAll("<@"+ds.bot.self.id.id+">", "@"+ds.bot.self.username));
    content.title = msg.id.id;
    if (!nodeValidator.allowsElement(content)) {
      _view.style.backgroundColor = "red";
      content.text = "<<Remote code execution protection has prevented this message from being displayed>>";
    }

    if(msg.attachments != null) {
      msg.attachments.forEach((s, attachment) {
        DocumentFragment attachmentFragment = document.importNode(
            attachmentTemplate.content, true);
        AnchorElement anchor = attachmentFragment.querySelector('a');
        ImageElement img = attachmentFragment.querySelector('img');
        anchor.href = attachment.url;
        if (attachment.filename.contains('.')) {
          final extension = attachment.filename
              .split('.')
              .last;
          if (['svg', 'tiff', 'gif', 'jpg', 'jpeg', 'png', 'webp'].contains(
              extension.toLowerCase())) {
            img.src = attachment.url;
            img.className = "attachment-image attachment-image-preview";
          } else {
            img.src =
                'https://mimetypeicons.gq/' + extension + '?size=scalable';
            img.className = "attachment-image attachment-image-unpreviewable";
          }
        }

        content.append(attachmentFragment);
      });
    }

    return avatar;
  }

  Future<Null> destroy() async {
    return null;
  }
}
