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
import '../../events/EmojiSelectionEvent.dart';

class EmojiController {
  final discord.GuildEmoji _emoji;
  final ImageElement _view;

  final StreamController<EmojiSelectionEvent> _onEmojiSelectionEventStreamController;
  final Stream<EmojiSelectionEvent> onEmojiSelectionEvent;

  EmojiController._internal(this._emoji, this._view, this._onEmojiSelectionEventStreamController, this.onEmojiSelectionEvent) {
    this._view.src = this._emoji.cdnUrl;
    this._view.title = this._emoji.nameString;

    this._view.addEventListener('click', (e) {
      _onEmojiSelectionEventStreamController.add(new EmojiSelectionEvent(_emoji));
    });
  }

  factory EmojiController(discord.Emoji _emoji, ImageElement _view) {
    StreamController<EmojiSelectionEvent> streamController = new StreamController<EmojiSelectionEvent>.broadcast();
    Stream<EmojiSelectionEvent> stream = streamController.stream;
    return EmojiController._internal(_emoji, _view, streamController, stream);
  }

  ImageElement get view => this._view;

  Future<Null> destroy() async {
    await this._onEmojiSelectionEventStreamController.close();
    return null;
  }
}
