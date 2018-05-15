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
import 'package:dartson/dartson.dart';
import 'package:discordshell/src/tabs/Tabs.dart';
import 'package:discordshell/src/tabs/Tab.dart';
import 'package:discordshell/src/model/AppSettings.dart';
import 'package:discordshell/src/model/DiscordShellBotCollection.dart';
import 'package:discordshell/src/model/DiscordShellBot.dart';
import 'package:discordshell/src/model/OpenTextChannelRequestEvent.dart';
import 'package:discordshell/src/model/OpenDMChannelRequestEvent.dart';
import 'package:discordshell/src/BotsController.dart';
import 'package:discordshell/src/chat/TextChannelChatController.dart';
import 'package:discordshell/src/chat/DMChatController.dart';
import 'package:discordshell/src/SettingsController.dart';

final DiscordShellBotCollection bots = new DiscordShellBotCollection();
final AppSettings appSettings = new AppSettings();

void main() {
  final Element tabsHTML = querySelector(".tabs");
  final TemplateElement botsControllerTemplate = querySelector('template#discord-shell-bots-controller-template');
  final TemplateElement chatControllerTemplate = querySelector('template#chat-pane-template');
  final TemplateElement helpTemplate = querySelector('template#help-template');
  final TemplateElement settingsTemplate = querySelector('template#settings-template');
  final Node settingsButtonElement = querySelector('header.site-header>svg');

  final Dartson dson = new Dartson.JSON();

  final String settingsStr = window.localStorage['settings'];
  if(settingsStr != null) {
    assert(settingsStr.length >= 0);
    final Object obj = dson.decode(window.localStorage['settings'], appSettings);
    assert(obj == appSettings);
  }

  final NodeValidatorBuilder nodeValidatorBuilder = new NodeValidatorBuilder();
  nodeValidatorBuilder.allowTextElements();
  nodeValidatorBuilder.allowImages();
  nodeValidatorBuilder.allowSvg();
  nodeValidatorBuilder.allowNavigation();
  nodeValidatorBuilder.allowHtml5();
  nodeValidatorBuilder.allowInlineStyles();

  tabsHTML.style.display = '';

  final DocumentFragment helpFragment = document.importNode(helpTemplate.content, true);
  final Tabs tabs = new Tabs(tabsHTML, helpFragment.querySelector('article.help'));

  final Map<DiscordShellBot, Map<String, Tab>> openedChatTabs = new HashMap<DiscordShellBot, Map<String, Tab>>();

  tabs.onNewTabRequest.listen((e) {
    final Tab botsControllerTab = new Tab(closable: true);
    tabs.addTab(botsControllerTab);

    BotsController botsController = new BotsController(
        bots,
        botsControllerTab.headerContent,
        botsControllerTab.tabContent,
        botsControllerTemplate
    );

    final StreamSubscription<OpenTextChannelRequestEvent> onOpenGuildTextChannelSubscription = botsController.onTextChannelRequestEvent.listen((chatOpenRequestEvent) {
      assert(chatOpenRequestEvent.channel != null);

      if(openedChatTabs.containsKey(chatOpenRequestEvent.ds) && openedChatTabs[chatOpenRequestEvent.ds].containsKey(chatOpenRequestEvent.channel.id)) {
        final Tab tab = openedChatTabs[chatOpenRequestEvent.ds][chatOpenRequestEvent.channel.id];
        tabs.activateTab(tab);
      } else {
        final Tab guildTab = new Tab(closable: true);
        final TextChannelChatController controller = new TextChannelChatController(
            chatOpenRequestEvent.ds,
            chatOpenRequestEvent.channel,
            guildTab.headerContent,
            guildTab.tabContent,
            chatControllerTemplate,
            nodeValidatorBuilder
        );
        if(openedChatTabs[chatOpenRequestEvent.ds] == null) {
          openedChatTabs[chatOpenRequestEvent.ds] = new HashMap<String, Tab>();
        }
        openedChatTabs[chatOpenRequestEvent.ds][chatOpenRequestEvent.channel.id] = guildTab;

        tabs.addTab(guildTab);

        StreamSubscription<OpenDMChannelRequestEvent> openDMChannelSubscription = controller.onOpenDMChannelRequestEvent.listen((dmOpenRequestEvent) {
          if(openedChatTabs.containsKey(dmOpenRequestEvent.ds) && openedChatTabs[dmOpenRequestEvent.ds].containsKey(dmOpenRequestEvent.channel.id)) {
            Tab tab = openedChatTabs[dmOpenRequestEvent.ds][dmOpenRequestEvent.channel.id];
            tabs.activateTab(tab);
          } else {
            assert(dmOpenRequestEvent.channel != null);
            Tab dmTab = new Tab(closable: true);
            DMChatController controller = new DMChatController(
                dmOpenRequestEvent.ds,
                dmOpenRequestEvent.channel,
                dmTab.headerContent,
                dmTab.tabContent,
                chatControllerTemplate,
                nodeValidatorBuilder
            );
            if (openedChatTabs[dmOpenRequestEvent.ds] == null) {
              openedChatTabs[dmOpenRequestEvent.ds] = new HashMap<String, Tab>();
            }
            openedChatTabs[dmOpenRequestEvent.ds][dmOpenRequestEvent.channel.id] = dmTab;

            tabs.addTab(dmTab);

            dmTab.onClose.listen((closeEvent) async {
              tabs.removeTab(dmTab);
              openedChatTabs[dmOpenRequestEvent.ds].remove(dmOpenRequestEvent.channel.id);
              await dmTab.destroy();
              await controller.destroy();
              return null;
            });
          }
        });

        guildTab.onClose.listen((closeEvent) async {
          tabs.removeTab(guildTab);
          openedChatTabs[chatOpenRequestEvent.ds].remove(chatOpenRequestEvent.channel.id);
          await openDMChannelSubscription.cancel();
          await guildTab.destroy();
          await controller.destroy();
          return null;
        });
      }
    });

    botsControllerTab.onClose.listen((e) async {
      tabs.removeTab(botsControllerTab);
      await botsControllerTab.destroy();
      await onOpenGuildTextChannelSubscription.cancel();
      await botsController.destroy();
      return null;
    });
  });

  settingsButtonElement.addEventListener('click', (e) {
    final Tab settingsTab = new Tab(closable: true);
    SettingsController settingsController = new SettingsController(
        appSettings,
        settingsTab.headerContent,
        settingsTab.tabContent,
        settingsTemplate);
    tabs.addTab(settingsTab);

    settingsTab.onClose.listen((e) async {
      tabs.removeTab(settingsTab);
      await settingsTab.destroy();
      await settingsController.destroy();
      return null;
    });
  });

  appSettings.onAppSettingsChangedEvent.listen((e) {
    requestNotificationPermissionIfNeeded(e.appSettings);
    window.localStorage['settings'] = dson.encode(e.appSettings);
  });
}

void requestNotificationPermissionIfNeeded(AppSettings appSettings) {
  if(appSettings.enableNotifications && appSettings.desktopNotifications) {
    if(Notification != null && Notification.supported) {
      Notification.requestPermission().then((result) {
        // result is a string which is either "granted" or "denied"
      }).catchError((e) {
        print(e);
      });
    }
  }
}
