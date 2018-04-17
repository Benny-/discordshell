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
import 'dart:collection';
import 'package:discord/discord.dart' as discord;
import 'package:discord/browser.dart' as discord;
import 'package:discordshell/src/tabs/Tabs.dart';
import 'package:discordshell/src/tabs/Tab.dart';
import 'package:discordshell/src/model/DiscordShellBotCollection.dart';
import 'package:discordshell/src/model/DiscordShellBot.dart';
import 'package:discordshell/src/model/OpenChannelRequestEvent.dart';
import 'package:discordshell/src/BotsController.dart';
import 'package:discordshell/src/chat/TextChannelChatController.dart';

DiscordShellBotCollection bots = new DiscordShellBotCollection();

void main() {
  Element tabsHTML = querySelector(".tabs");
  TemplateElement botsControllerTemplate = querySelector('template#discord-shell-bots-controller-template');
  TemplateElement chatControllerTemplate = querySelector('template#chat-pane-template');
  TemplateElement helpTemplate = querySelector('template#help-template');

  NodeValidatorBuilder nodeValidatorBuilder = new NodeValidatorBuilder();
  nodeValidatorBuilder.allowTextElements();
  nodeValidatorBuilder.allowImages();
  nodeValidatorBuilder.allowSvg();
  nodeValidatorBuilder.allowNavigation();
  nodeValidatorBuilder.allowHtml5();
  nodeValidatorBuilder.allowInlineStyles();

  tabsHTML.style.display = '';

  DocumentFragment helpFragment = document.importNode(helpTemplate.content, true);
  Tabs tabs = new Tabs(tabsHTML, helpFragment.querySelector('article.help'));

  Map<DiscordShellBot, Map<String, Tab>> openedChatTabs = new HashMap<DiscordShellBot, Map<String, Tab>>();

  tabs.onNewTabRequest.listen((e) {
    Tab tab = new Tab(closable: true);
    tabs.addTab(tab);

    BotsController botsController = new BotsController(
        bots,
        tab.headerContent,
        tab.tabContent,
        botsControllerTemplate
    );

    StreamSubscription<OpenChannelRequestEvent> subscription = botsController.onOpenChannelRequestEvent.listen((e) {
      assert(e.channel != null);

      if(openedChatTabs.containsKey(e.ds) && openedChatTabs[e.ds].containsKey(e.channel.id)) {
        Tab tab = openedChatTabs[e.ds][e.channel.id];
        tabs.activateTab(tab);
      } else {

        if(e.channel is discord.TextChannel) {
          Tab tab = new Tab(closable: true);
          TextChannelChatController controller = new TextChannelChatController(
              e.ds,
              e.channel,
              tab.headerContent,
              tab.tabContent,
              chatControllerTemplate,
              nodeValidatorBuilder
          );

          if(openedChatTabs[e.ds] == null) {
            openedChatTabs[e.ds] = new HashMap<String, Tab>();
          }
          openedChatTabs[e.ds][e.channel.id] = tab;

          tabs.addTab(tab);

          tab.onClose.listen((closeEvent) async {
            tabs.removeTab(tab);
            openedChatTabs[e.ds].remove(e.channel.id);
            await tab.destroy();
            await controller.destroy();
            return null;
          });
        }

        if(e.channel is discord.DMChannel) {
          // TODO: Implement DMChannel chat controller
        }

        if(e.channel is discord.GroupDMChannel) {
          // TODO: Implement GroupDMChannel chat controller
        }
      }
    });

    tab.onClose.listen((e) async {
      tabs.removeTab(tab);
      await tab.destroy();
      await botsController.destroy();
      await subscription.cancel();
      return null;
    });

  });
}
