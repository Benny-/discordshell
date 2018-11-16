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
import '../../events/EmojiSelectionEvent.dart';
import './EmojiController.dart';

class EmojiSelectorController {
  final DiscordShellBot _ds;
  final DivElement _view;

  final StreamController<EmojiSelectionEvent> _onEmojiSelectionEventStreamController;
  final Stream<EmojiSelectionEvent> onEmojiSelectionEvent;

  final TemplateElement _emojiTemplate;

  StreamSubscription<discord.GuildEmojisUpdateEvent> _emojiUpdateSubscription;
  StreamSubscription<discord.GuildCreateEvent> _guildCreateEventSubscription;

  final List<EmojiController> _emojis = new List();
  EmojiSelectorController._internal(this._ds, this._view, this._onEmojiSelectionEventStreamController, this.onEmojiSelectionEvent):
        _emojiTemplate = _view.querySelector("template[name=emoji]") {
    assert(_ds != null);
    assert(_view != null);
    assert(_emojiTemplate != null);

    this._rebuildEmojis();
    this._emojiUpdateSubscription = this._ds.bot.onGuildEmojisUpdate.listen((discord.GuildEmojisUpdateEvent e) {
      this._rebuildEmojis();
    });

    this._guildCreateEventSubscription = this._ds.bot.onGuildCreate.listen((e) {
      this._rebuildEmojis();
    });
  }

  factory EmojiSelectorController(DiscordShellBot _ds, DivElement _view) {
    StreamController<EmojiSelectionEvent> streamController = new StreamController<EmojiSelectionEvent>.broadcast();
    Stream<EmojiSelectionEvent> stream = streamController.stream;
    return EmojiSelectorController._internal(_ds, _view, streamController, stream);
  }

  DivElement get view => this._view;

  _rebuildEmojis() {

    for(EmojiController e in this._emojis) {
      e.view.remove();
      e.destroy();
    }
    _emojis.clear();

    this._ds.bot.guilds.forEach((snowflake, guild) {
      guild.emojis.forEach((snowflake, guildEmoji) {
        DocumentFragment fragment = document.importNode(_emojiTemplate.content, true);
        ImageElement image = fragment.querySelector('img');
        this._view.append(image);
        final EmojiController emojiController = new EmojiController(guildEmoji, image);
        emojiController.onEmojiSelectionEvent.listen((e) {
          this._onEmojiSelectionEventStreamController.add(e);
        });
        this._emojis.add(emojiController);
      });
    });
  }

  Future<Null> destroy() async {
    await this._onEmojiSelectionEventStreamController.close();
    await this._emojiUpdateSubscription.cancel();
    await this._guildCreateEventSubscription.cancel();
    for(EmojiController e in this._emojis) {
      await e.destroy();
    }
    return null;
  }
}
