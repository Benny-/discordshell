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
import './model/DiscordShellBot.dart';
import './GuildController.dart';
import 'package:discordshell/src/events/OpenTextChannelRequestEvent.dart';

class BotController {
  final DiscordShellBot _ds;
  final DivElement _view;
  final List<GuildController> _subControllers = new List<GuildController>();

  final ImageElement _userAvatarHTML;
  final HtmlElement _userNameHTML;
  final HtmlElement _userDiscriminatorHTML;
  final AnchorElement _userIdHTML;
  final DivElement _guildPanesHTML;
  final HtmlElement _botStatusHTML;
  final DivElement _guildContainer;
  final TemplateElement _guildTemplate;

  final StreamController<OpenTextChannelRequestEvent> _onTextChannelRequestEventStreamController;
  final Stream<OpenTextChannelRequestEvent> onTextChannelRequestEvent;

  BotController._internal(this._ds, this._view, this._onTextChannelRequestEventStreamController, this.onTextChannelRequestEvent) :
    _userAvatarHTML = _view.querySelector('img.user-avatar'),
    _userNameHTML = _view.querySelector('.user-name'),
    _userDiscriminatorHTML = _view.querySelector('.discriminator'),
    _userIdHTML = _view.querySelector('a.discord-user-id'),
    _guildPanesHTML = _view.querySelector('div.guild-panes'),
    _botStatusHTML = _view.querySelector('.discord-shell-status'),
    _guildContainer = _view.querySelector('.guild-panes'),
    _guildTemplate = _view.querySelector('template[name="guild-pane-template"]')
  {
    assert(this._ds != null);
    assert(this._view != null);
    assert(this._userAvatarHTML != null);
    assert(this._userNameHTML != null);
    assert(this._userDiscriminatorHTML != null);
    assert(this._userIdHTML != null);
    assert(this._guildPanesHTML != null);
    assert(this._botStatusHTML != null);
    assert(this._guildContainer != null);
    assert(this._guildTemplate != null);

    if(this._ds.bot.ready) {
      this._ready();
    } else {
      StreamSubscription<discord.ReadyEvent> subscription;
      subscription = this._ds.bot.onReady.listen((e) async {
        this._ready();
        return subscription.cancel();
      });
    }

    this._ds.bot.onHttpError.listen((e) {
      _botStatusHTML.text = "An HTTP error occured. " + e.response.statusText;
    });

    this._ds.bot.onDisconnect.listen((e) {
      _botStatusHTML.text = "Disconnected with code " + e.closeCode.toString();
    });
  }

  factory BotController(DiscordShellBot discordShell, HtmlElement parent, TemplateElement template) {
    DocumentFragment fragment = document.importNode(template.content, true);
    DivElement view = fragment.querySelector('div.discord-shell-bot-controller');
    parent.append(fragment);

    StreamController<OpenTextChannelRequestEvent> streamController = new StreamController<OpenTextChannelRequestEvent>.broadcast();
    Stream<OpenTextChannelRequestEvent> stream = streamController.stream;

    return new BotController._internal(discordShell, view, streamController, stream);
  }

  _createGuildEvent(discord.Guild guild) {
    GuildController controller = new GuildController(this._ds, guild, _guildContainer, _guildTemplate);
    controller.onTextChannelRequestEvent.listen((e) {
      this._onTextChannelRequestEventStreamController.add(e);
    });
    this._subControllers.add(controller);
  }

  _ready() {
    this._botStatusHTML.text = this._ds.status;
    this._userNameHTML.text = this._ds.bot.self.username;
    this._userDiscriminatorHTML.text = "#" + this._ds.bot.self.discriminator;
    this._userAvatarHTML.src = this._ds.bot.self.avatarURL(format: 'png');
    this._userIdHTML.text = this._ds.bot.self.id.id;
    this._userIdHTML.href = 'https://discordapp.com/oauth2/authorize?client_id=' + this._ds.bot.self.id.id + '&scope=bot';

    this._ds.bot.guilds.forEach((key, guild) {
      this._createGuildEvent(guild);
    });

    this._ds.bot.onGuildCreate.listen((discord.GuildCreateEvent e) {
      bool alreadyFound = false;

      for(GuildController gc in this._subControllers) {
        discord.Guild guild = gc.guild;

        if(guild.id == e.guild.id)
          alreadyFound = true;
      }

      if(!alreadyFound)
        this._createGuildEvent(e.guild);
    });
  }

  Future<Null> destroy() async {
    await this._onTextChannelRequestEventStreamController.close();
    for(GuildController controller in this._subControllers) {
      await controller.destroy();
    }
    return null;
  }
}
