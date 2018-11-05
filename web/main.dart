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
import 'dart:convert';
import 'dart:collection';
import 'package:nyxx/Browser.dart' show configureNyxxForBrowser;
import 'package:nyxx/nyxx.dart' show Channel, DMChannel, Snowflake, TextChannel;
import 'package:discordshell/src/notifications/NotificationArea.dart';
import 'package:discordshell/src/notifications/NotificationPopup.dart';
import 'package:discordshell/src/tabs/Tabs.dart';
import 'package:discordshell/src/tabs/Tab.dart';
import 'package:discordshell/src/discordshell/model/AppSettings.dart';
import 'package:discordshell/src/discordshell/model/DiscordShellBotCollection.dart';
import 'package:discordshell/src/discordshell/model/DiscordShellBot.dart';
import 'package:discordshell/src/discordshell/events/OpenTextChannelRequestEvent.dart';
import 'package:discordshell/src/discordshell/events/OpenDMChannelRequestEvent.dart';
import 'package:discordshell/src/discordshell/viewcontroller/BotsController.dart';
import 'package:discordshell/src/discordshell/viewcontroller/chat/TextChannelChatController.dart';
import 'package:discordshell/src/discordshell/viewcontroller/chat/DMChatController.dart';
import 'package:discordshell/src/discordshell/viewcontroller/SettingsController.dart';

AppSettings loadSettings() {
  final String settingsStr = window.localStorage['settings'];
  if(settingsStr != null) {
    assert(settingsStr.length >= 0);
    final json = jsonDecode(settingsStr);
    return AppSettings.fromJson(json);
  } else {
    return new AppSettings();
  }
}

void main() {
  configureNyxxForBrowser();
  final Element tabsHTML = querySelector(".tabs");
  final TemplateElement botsControllerTemplate = querySelector('template#discord-shell-bots-controller-template');
  final TemplateElement chatControllerTemplate = querySelector('template#chat-pane-template');
  final TemplateElement helpTemplate = querySelector('template#help-template');
  final TemplateElement settingsTemplate = querySelector('template#settings-template');
  final Node settingsButtonElement = querySelector('header.site-header>svg');
  final NotificationArea notificationArea = new NotificationArea(querySelector('div#notification-area'));

  final DiscordShellBotCollection bots = new DiscordShellBotCollection();
  final AppSettings appSettings = loadSettings();
  final Map<DiscordShellBot, Map<Snowflake, Tab>> openedChatTabs = new HashMap<DiscordShellBot, Map<Snowflake, Tab>>();

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
      Tab tab = openGuildTextChannel(chatOpenRequestEvent.channel,
          chatOpenRequestEvent.ds,
          openedChatTabs,
          tabs,
          chatControllerTemplate,
          nodeValidatorBuilder);
      tabs.focusTab(tab);
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

  bots.onNewDiscordShell.listen((newDiscordShellEvent) {
    newDiscordShellEvent.discordShell.bot.onMessage.listen((newMessageEvent) {

      bool messageInOpenTab = (openedChatTabs[newDiscordShellEvent.discordShell] != null) && (openedChatTabs[newDiscordShellEvent.discordShell][newMessageEvent.message.channel.id] != null);
      bool messageContainsMention = newMessageEvent.message.content.contains("<@"+newDiscordShellEvent.discordShell.bot.self.id.id+">");
      bool isDM = newMessageEvent.message.channel is DMChannel;
      bool isOwnMessage = newMessageEvent.message.author.id == newDiscordShellEvent.discordShell.bot.self.id;

      if(isDM) {
        openDMChannel(newMessageEvent.message.channel,
            newDiscordShellEvent.discordShell,
            openedChatTabs,
            tabs,
            chatControllerTemplate,
            nodeValidatorBuilder);
      }

      if(appSettings.enableNotifications && !isOwnMessage) {
        if((appSettings.enableMentionNotifications && messageContainsMention)
            || (appSettings.enableOpenTabNotifications && messageInOpenTab)
            || (appSettings.enableOpenTabMentionNotifications && messageInOpenTab && messageContainsMention)
            || isDM) {

          String body = newMessageEvent.message.content;
          // TODO: Properly replace all mentions in body and take code block into account.
          body = body.replaceAll("<@"+newDiscordShellEvent.discordShell.bot.self.id.id+">", "@"+newDiscordShellEvent.discordShell.bot.self.username);
          final Channel channel = newMessageEvent.message.channel;
          String title = "DiscordShell";
          String icon = "images/robocord.png";

          if(newDiscordShellEvent.discordShell.bot.self.avatar != null) {
            icon = newDiscordShellEvent.discordShell.bot.self.avatarURL(format: 'png', size: 128);
          }

          if(channel is DMChannel) {
            title = channel.recipient.username;
            icon = "images/iconless.png";
            if(channel.recipient.avatar != null) {
              icon = channel.recipient.avatarURL(format: 'png', size: 128);
            }
          } else if(channel is TextChannel) {
            title = channel.guild.name;
            if(channel.guild.icon != null) {
              icon = channel.guild.iconURL(format: 'png', size: 128);
            }
          } else {
            assert(false);
          }

          if(Notification != null && Notification.supported && appSettings.desktopNotifications) {
            Notification notification = new Notification(title, body:body, icon:icon);
            notification.onClick.listen((e) {
              Tab tab = openChannel(channel, newDiscordShellEvent.discordShell, openedChatTabs, tabs, chatControllerTemplate, nodeValidatorBuilder);
              tabs.focusTab(tab);
              notification.close();
            });
          } else {
            NotificationPopup notification = notificationArea.notification(title, body, icon);
            notification.addClickEventListener((E) {
              Tab tab = openChannel(channel, newDiscordShellEvent.discordShell, openedChatTabs, tabs, chatControllerTemplate, nodeValidatorBuilder);
              tabs.focusTab(tab);
              notification.destroy();
            });
            notification.start();
          }
        }
      }
    });
  });

  appSettings.onAppSettingsChangedEvent.listen((e) {
    requestNotificationPermissionIfNeeded(e.appSettings);
    window.localStorage['settings'] = e.appSettings.toJson().toString();
  });
}

Tab openDMChannel(DMChannel channel,
    DiscordShellBot ds,
    Map<DiscordShellBot, Map<Snowflake, Tab>> openedChatTabs,
    Tabs tabs,
    TemplateElement chatControllerTemplate,
    NodeValidatorBuilder nodeValidatorBuilder) {
  if(openedChatTabs.containsKey(ds) && openedChatTabs[ds].containsKey(channel.id)) {
    Tab tab = openedChatTabs[ds][channel.id];
    return tab;
  } else {
    assert(channel != null);
    Tab dmTab = new Tab(closable: true);
    DMChatController controller = new DMChatController(
        ds,
        channel,
        dmTab.headerContent,
        dmTab.tabContent,
        chatControllerTemplate,
        nodeValidatorBuilder
    );
    if (openedChatTabs[ds] == null) {
      openedChatTabs[ds] = new HashMap<Snowflake, Tab>();
    }
    openedChatTabs[ds][channel.id] = dmTab;

    tabs.addTab(dmTab, activate: false);

    dmTab.onClose.listen((closeEvent) async {
      tabs.removeTab(dmTab);
      openedChatTabs[ds].remove(channel.id);
      await dmTab.destroy();
      await controller.destroy();
      return null;
    });

    return dmTab;
  }
}

Tab openGuildTextChannel(
    TextChannel channel,
    DiscordShellBot ds,
    Map<DiscordShellBot, Map<Snowflake, Tab>> openedChatTabs,
    Tabs tabs,
    TemplateElement chatControllerTemplate,
    NodeValidatorBuilder nodeValidatorBuilder) {
  if(openedChatTabs.containsKey(ds) && openedChatTabs[ds].containsKey(channel.id)) {
    final Tab tab = openedChatTabs[ds][channel.id];
    return tab;
  } else {
    final Tab guildTab = new Tab(closable: true);
    final TextChannelChatController controller = new TextChannelChatController(
        ds,
        channel,
        guildTab.headerContent,
        guildTab.tabContent,
        chatControllerTemplate,
        nodeValidatorBuilder
    );
    if(openedChatTabs[ds] == null) {
      openedChatTabs[ds] = new HashMap<Snowflake, Tab>();
    }
    openedChatTabs[ds][channel.id] = guildTab;

    tabs.addTab(guildTab, activate: false);

    StreamSubscription<OpenDMChannelRequestEvent> openDMChannelSubscription = controller.onOpenDMChannelRequestEvent.listen((dmOpenRequestEvent) {
      Tab tab = openDMChannel(dmOpenRequestEvent.channel,
          dmOpenRequestEvent.ds,
          openedChatTabs,
          tabs,
          chatControllerTemplate,
          nodeValidatorBuilder);
      tabs.focusTab(tab);
    });

    guildTab.onClose.listen((closeEvent) async {
      tabs.removeTab(guildTab);
      openedChatTabs[ds].remove(channel.id);
      await openDMChannelSubscription.cancel();
      await guildTab.destroy();
      await controller.destroy();
      return null;
    });

    return guildTab;
  }
}

Tab openChannel(
    Channel channel,
    DiscordShellBot ds,
    Map<DiscordShellBot, Map<Snowflake, Tab>> openedChatTabs,
    Tabs tabs,
    TemplateElement chatControllerTemplate,
    NodeValidatorBuilder nodeValidatorBuilder) {
  if(channel is DMChannel) {
    return openDMChannel(channel, ds, openedChatTabs, tabs, chatControllerTemplate, nodeValidatorBuilder);
  } else if (channel is TextChannel) {
    return openGuildTextChannel(channel, ds, openedChatTabs, tabs, chatControllerTemplate, nodeValidatorBuilder);
  } else {
    assert(false);
    return null;
  }
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
