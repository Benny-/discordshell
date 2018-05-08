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
import './model/DiscordShellBot.dart';
import 'package:discordshell/src/model/DiscordShellBotCollection.dart';
import './BotController.dart';
import 'package:discordshell/src/model/OpenTextChannelRequestEvent.dart';

class BotsController {
  final DiscordShellBotCollection _dsCollection;
  final TemplateElement _botTemplate;
  final List<BotController> _subControllers = new List<BotController>();

  final HtmlElement _titleContainer;

  final HtmlElement _view;

  final StreamController<OpenTextChannelRequestEvent> _onTextChannelRequestEventStreamController;
  final Stream<OpenTextChannelRequestEvent> onTextChannelRequestEvent;

  BotsController._internal(this._dsCollection,
      this._titleContainer,
      this._view,
      this._botTemplate,
      this._onTextChannelRequestEventStreamController,
      this.onTextChannelRequestEvent)
  {
    this._titleContainer.text = "Bots";

    for(DiscordShellBot discordShell in this._dsCollection.discordShells) {
      this._addChannelSelectorForDiscordShell(discordShell);
    }

    this._dsCollection.onNewDiscordShell.listen((e) {
      this._addChannelSelectorForDiscordShell(e.discordShell);
    });

    FormElement tokenForm = this._view.querySelector('form.bot-token-form');
    InputElement tokenInput = this._view.querySelector('input[name="token"]');
    InputElement tokenSubmit = this._view.querySelector('input[type="submit"]');

    tokenSubmit.disabled = tokenInput.value.length < 1;
    tokenInput.addEventListener('input', (e) {
      tokenSubmit.disabled = tokenInput.value.length < 1;
    });

    tokenForm.addEventListener('submit', (e) {
      DiscordShellBot discordShell = new DiscordShellBot(tokenInput.value);
      this._dsCollection.addDiscordShell(discordShell);
      tokenInput.value = "";
      tokenSubmit.disabled = tokenInput.value.length < 1;
      e.preventDefault();
    });
  }

  factory BotsController(DiscordShellBotCollection
      _dsCollection,
      HtmlElement _titleContainer,
      HtmlElement _contentContainer,
      TemplateElement managerTemplate) {
    DocumentFragment fragment = document.importNode(managerTemplate.content, true);
    TemplateElement botTemplate = fragment.querySelector('template[name="discord-shell-bot-controller-template"]');
    DivElement view = fragment.querySelector('div.discord-shell-bots-controller');
    _contentContainer.append(fragment);

    StreamController<OpenTextChannelRequestEvent> streamController = new StreamController<OpenTextChannelRequestEvent>.broadcast();
    Stream<OpenTextChannelRequestEvent> stream = streamController.stream;

    return new BotsController._internal(
        _dsCollection,
        _titleContainer,
        view,
        botTemplate,
        streamController,
        stream
    );
  }

  _addChannelSelectorForDiscordShell(DiscordShellBot discordShell) {
    BotController botController = new BotController(
        discordShell,
        this._view,
        this._botTemplate
    );
    botController.onTextChannelRequestEvent.listen((e) {
      this._onTextChannelRequestEventStreamController.add(e);
    });
    _subControllers.add(botController);
  }

  Future<Null> destroy() async {
    await this._onTextChannelRequestEventStreamController.close();
    for(BotController controller in this._subControllers) {
      await controller.destroy();
    }
    return null;
  }
}
