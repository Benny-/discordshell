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
import '../../events/OpenDMChannelRequestEvent.dart';
import './MessageChannelController.dart';

class TextChannelChatController extends MessageChannelController {
  final discord.TextChannel _channel;

  final StreamController<OpenDMChannelRequestEvent> _onOpenDMChannelRequestEventStreamController;
  final Stream<OpenDMChannelRequestEvent> onOpenDMChannelRequestEvent;

  final DivElement _profileBar;
  discord.Member _profile;
  final TemplateElement _userTemplate;
  final DivElement _usersList;

  TextChannelChatController._internal (
      DiscordShellBot _ds,
      this._channel,
      HtmlElement _titleContainer,
      DivElement view,
      this._onOpenDMChannelRequestEventStreamController,
      this.onOpenDMChannelRequestEvent,
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
    assert(_userTemplate != null);
    assert(_profileBar != null);
          
    ImageElement titleIcon = new ImageElement( src: this.ds.bot.self.avatarURL(format: 'png'), width: 128, height: 128);
    titleIcon.className = "user-avatar-tab-header";
    SpanElement titleText = new SpanElement();
    titleText.text = _channel.name;

    this.titleContainer.append(titleIcon);
    this.titleContainer.appendText(' ');
    this.titleContainer.append(titleText);

    _profileBar.style.position = "absolute";
    _profileBar.querySelector(".profile-name-tag").children[0].addEventListener('click', (e){
      if(!_profile.bot) {
        _profileBar.style.display = "none";
        _profile.dmChannel.then((k){
          OpenDMChannelRequestEvent e = new OpenDMChannelRequestEvent(this.ds, k);
          _onOpenDMChannelRequestEventStreamController.add(e);
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

    for(discord.Member member in this._channel.guild.members.values) {
      // TODO: Restrict the list of members to who can see this channel
      this._addMember(member);
    }
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

  discord.TextChannel get channel => this._channel;

  _addMember(discord.Member user) {
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
    await this._onOpenDMChannelRequestEventStreamController.close();
    return await super.destroy();
  }
}
