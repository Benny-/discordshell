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
import '../../model/DiscordShellBot.dart';
import './MessageChannelController.dart';

class DMChatController extends MessageChannelController {
  final discord.DMChannel _channel;

  DivElement _profileBar;
  discord.User _profile;
  final TemplateElement _userTemplate;
  final DivElement _usersList;

  DMChatController._internal(
      DiscordShellBot _ds,
      this._channel,
      HtmlElement _titleContainer,
      DivElement view,
      NodeValidator nodeValidator)
      : _profileBar = view.querySelector(".profile-bar"),
        _usersList = view.querySelector(".users-list"),
        _userTemplate = view.querySelector("template[name=user-template]"),
        super(_ds,
              nodeValidator,
              _titleContainer,
              view,
              view.querySelector(".chat-messages"),
              view.querySelector("textarea"),
              view.querySelector(".typing"),
              view.querySelector(".profile-bar"),
              view.querySelector(".editbarbox"),
              view.querySelector("template[name=message-template]"),
              view.querySelector("template[name=message-attachment]")
        )
  {
    assert(_channel != null);
    assert(_usersList != null);
    assert(_profileBar != null);
    assert(_userTemplate != null);

    this.titleContainer.text = _channel.recipient.username;

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

  discord.MessageChannel get channel => this._channel;

  Future<Null> destroy() async {
    return await super.destroy();
  }
}
