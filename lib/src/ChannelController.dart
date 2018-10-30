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
import 'dart:async';
import 'dart:html';
import 'package:nyxx/nyxx.dart' as discord;
import './model/DiscordShellBot.dart';
import 'package:discordshell/src/events/OpenTextChannelRequestEvent.dart';

class ChannelController {
  final DiscordShellBot _ds;
  discord.TextChannel _channel;
  final DivElement _view;

  final StreamController<OpenTextChannelRequestEvent> _onTextChannelRequestEventStreamController;
  final Stream<OpenTextChannelRequestEvent> onTextChannelRequestEvent;

  ChannelController._internal(this._ds, this._channel, this._view, this._onTextChannelRequestEventStreamController, this.onTextChannelRequestEvent) {
    this._ds.bot.onChannelUpdate.listen((e) {
      assert(e.oldChannel.id != _channel.id || (e.oldChannel.id == _channel.id && e.oldChannel == _channel));

      if(_channel == e.oldChannel) {
        _channel = e.newChannel;
        this.updateView();
      }
    });

    this._ds.bot.onChannelDelete.listen((e) {
      assert(e.channel.id != _channel.id || (e.channel.id == _channel.id && e.channel == _channel));

      if(_channel == e.channel) {
        this._view.classes.add('deleted-channel');
      }
    });

    this._view.addEventListener('click', (DomEvent) {
      OpenTextChannelRequestEvent e = new OpenTextChannelRequestEvent(this._ds, this._channel);
      _onTextChannelRequestEventStreamController.add(e);
    });

    this.updateView();
  }

  factory ChannelController(DiscordShellBot ds, discord.TextChannel channel, HtmlElement parent, TemplateElement _guildTemplate) {
    DocumentFragment fragment = document.importNode(_guildTemplate.content, true);
    DivElement view = fragment.querySelector('div.channel');
    parent.append(view);

    StreamController<OpenTextChannelRequestEvent> streamController = new StreamController<OpenTextChannelRequestEvent>.broadcast();
    Stream<OpenTextChannelRequestEvent> stream = streamController.stream;

    return new ChannelController._internal(ds, channel, view, streamController, stream);
  }

  updateView() {
    this._view.text = '#' + _channel.name;
    this._view.title = _channel.id.id;
  }

  Future<Null> destroy() async {
    await this._onTextChannelRequestEventStreamController.close();
    return null;
  }
}
