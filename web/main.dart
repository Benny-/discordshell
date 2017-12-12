/*
BSD 3-Clause License

Copyright (c) 2017, Benny Jacobs
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
import 'dart:convert';
import 'package:discordshell/src/DiscordShell.dart';

void main() {
  Element controlsHTML = querySelector("#controls");
  Element botsHTML = querySelector('#bots');
  Element statusHTML = querySelector('#status');
  TemplateElement discordBotTemplate = querySelector('template#discord-shell-template');

  statusHTML.text = "Fetching settings~";
  HttpRequest.getString("settings.json").then((responseText) {
    Map parsedMap = JSON.decode(responseText);
    DocumentFragment botDom = document.importNode(discordBotTemplate.content, true);
    DiscordShell discordShell = new DiscordShell(botDom, parsedMap['token']);
    assert(botDom != null);
    botsHTML.append(botDom);
    botsHTML.style.display = '';
  }).catchError((e) {
    print("No settings file found. That is okay, the settings file is used to immediatly login as a bot. You can still add bots on your own.");
  }).whenComplete(() {
    // Allow the user to add new bots.
    controlsHTML.style.display = '';
    statusHTML.text = 'Control discord bots';

    InputElement input = controlsHTML.querySelector("input");
    ButtonElement button = controlsHTML.querySelector("button");

    button.disabled = true;
    button.addEventListener('click', (e) {
      DocumentFragment botDom = document.importNode(discordBotTemplate.content, true);
      DiscordShell discordShell = new DiscordShell(botDom, input.value);
      botsHTML.append(botDom);
      botsHTML.style.display = '';
    });

    input.addEventListener('input', (e) {
      button.disabled = input.value.length == 0;
    });

  });
}
