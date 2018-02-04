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
import 'package:discord/discord.dart' as discord;
import 'package:discord/browser.dart' as discord;

class ChatPane {

  final SelectElement channelSelector;
  final Element messages;
  final TextAreaElement textArea;
  final TemplateElement messageTemplate;
  final discord.Client bot;

  final Map<OptionElement, discord.TextChannel> optionToChannel = new Map<OptionElement, discord.TextChannel>();

  discord.TextChannel selectedChannel = null;

  ChatPane (DocumentFragment container, this.bot) :
    channelSelector = container.querySelector("select.channel-selector"),
    messages = container.querySelector(".chat-messages"),
    textArea = container.querySelector("textarea"),
    messageTemplate = container.querySelector("template[name=message-template]")
  {
    this.rebuildChannelSelector();
    assert(messages != null);

    bot.onMessage.listen((discord.MessageEvent e) {
      assert(e.message.channel != null);
      if(e.message.channel == this.selectedChannel)
      {
        DocumentFragment msg = document.importNode(messageTemplate.content, true);
        msg.querySelector(".user-name").text = e.message.author.username;
        msg.querySelector(".content").text = e.message.content;
        messages.append(msg);
      }
      else
      {
        assert(this.selectedChannel == null || (e.message.channel.id != this.selectedChannel.id));
      }
    });

    ButtonElement chatButton = container.querySelector("button");
    chatButton.addEventListener('click', (e) {
      String text = this.textArea.value;
      if(text.length > 0)
      {
        selectedChannel.send(content: text);
      }
      this.textArea.value = '';
      chatButton.disabled = true;
    });

    chatButton.disabled = true;
    this.textArea.addEventListener('input', (e) {
      chatButton.disabled = this.textArea.value.length == 0;
    });

    channelSelector.addEventListener('change', (e) {
      discord.TextChannel channel = optionToChannel[channelSelector.selectedOptions.first];

      if(channel == selectedChannel)
      {
        return;
      }

      channel.getMessages().then((messages) {
        for(Element msg in this.messages.querySelectorAll(".message"))
        {
          msg.remove();
        }
        selectedChannel = channel;

        List<discord.Message> list = new List<discord.Message>();

        for (const msg in messages.values)
        {
          list.add(msg);
        }

        list.sort((a, b) {
          return a.timestamp.compareTo(b.timestamp);
        });

        list.forEach((message) {
          DocumentFragment msg = document.importNode(messageTemplate.content, true);
          msg.querySelector(".user-name").text = message.author.username;
          msg.querySelector(".content").text = message.content;
          this.messages.append(msg);
        });
      });
    });
  }

  rebuildChannelSelector() {
    optionToChannel.clear();
    for(var guild in bot.guilds.values)
    {
      OptGroupElement optGroup = new OptGroupElement();
      optGroup.label = guild.name;
      channelSelector.append(optGroup);
      for(var channel in guild.channels.values)
      {
        if(channel.type == 'text')
        {
          discord.TextChannel textChannel = channel;
          OptionElement option = new OptionElement();
          option.text = channel.name;
          option.value = channel.id;
          channelSelector.append(option);
          optionToChannel[option] = textChannel;
        }
      }
    }
  }

}
