import 'dart:html';
import 'dart:convert';
import 'package:discord/discord.dart' as discord;
import 'package:discord/browser.dart' as discord;

discord.Guild guild = null;
Element statusHTML = querySelector('#status');
Element guildsHTML = querySelector('.guilds-pane');
TemplateElement guildTemplateHTML = querySelector('template#guild-template');

void onAppSettings(String responseText) {
  statusHTML.text = 'Running~';
  Map parsedMap = JSON.decode(responseText);

  discord.configureDiscordForBrowser();
  discord.Client bot = new discord.Client(parsedMap['token']);

  bot.onReady.listen((discord.ReadyEvent e) async {
    statusHTML.text = 'Ready';
    bot.guilds.forEach((key, guild) {
        print("Init guild: " + guild.name);

        DocumentFragment guildContainer = document.importNode(guildTemplateHTML.content, true);
        Element title = guildContainer.querySelector('.guild-name');
        title.text = guild.name;

        guildsHTML.append(guildContainer);
    });
  });

  bot.onGuildCreate.listen((discord.GuildCreateEvent e) {
    print("Joined" + " " + e.guild.name);
    guild = e.guild;
  });

  bot.onGuildUpdate.listen((discord.GuildUpdateEvent e) {
    if(e.oldGuild.name != e.newGuild.name)
    {
      print("Guild" + " " + e.oldGuild.name + " " + "changed into" + " " + e.newGuild.name);
    }
    else
    {
      print("Guild" + " " + e.newGuild.name + " " + "changed");
    }
  });

  bot.onGuildDelete.listen((discord.GuildDeleteEvent e) {
    print("Left" + " " + e.guild.name);
  });

  bot.onMessage.listen((discord.MessageEvent e) {
    print("Received msg on" + " " + e.message.guild.name + " : " + e.message.content);
    print("Guild equal: " + ((guild == e.message.guild)?"True":"False") );
  });
}

void main() {
  statusHTML.text = "Fetching settings~";
  HttpRequest.getString("settings.json").then(onAppSettings);
}
