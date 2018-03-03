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
import 'package:markdown/markdown.dart';

class ChatPane {

  final SelectElement channelSelector;
  final DivElement messages;
  final TextAreaElement textArea;
  final TemplateElement messageTemplate;
  final TemplateElement userTemplate;
  final DivElement userslist;
  final discord.Client bot;
  final NodeValidator nodeValidator;

  final Map<OptionElement, discord.TextChannel> optionToChannel = new Map<OptionElement, discord.TextChannel>();

  discord.TextChannel selectedChannel = null;

  ChatPane (DocumentFragment container, this.nodeValidator, this.bot) :
    channelSelector = container.querySelector("select.channel-selector"),
    messages = container.querySelector(".chat-messages"),
    userslist = container.querySelector(".users-list"),
    textArea = container.querySelector("textarea"),
    userTemplate = container.querySelector("template[name=user-template]"),
    messageTemplate = container.querySelector("template[name=message-template]")
  {
    this.rebuildChannelSelector();
    assert(messages != null);

    bot.onMessage.listen((discord.MessageEvent e) {
      assert(e.message.channel != null);
      if(e.message.channel == this.selectedChannel)
      {
        this.addMessage(e.message);
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
  
  bot.onPresenceUpdate.listen((discord.PresenceUpdateEvent e){
    if(e.newMember.guild==selectedChannel.guild){
      DivElement userlistitem = document.querySelector(".users-list");
      HtmlElement avatar = userlistitem.querySelector("[title='"+e.newMember.id+"']");
      ImageElement picture = avatar.parent.querySelector("img");
      picture.className=e.newMember.status;
    }
  });

    channelSelector.addEventListener('change', (e) {
      discord.TextChannel channel = optionToChannel[channelSelector.selectedOptions.first];

      if(channel == selectedChannel)
      {
        return;
      }

      channel.getMessages().then((messages) {
        for(DivElement msg in this.messages.querySelectorAll(".message"))
        {
          msg.remove();
        }
        List<discord.Member> userlist = new List<discord.Member>();
        //Check if different server
        if (selectedChannel == null||selectedChannel.guild.id != channel.guild.id){
          for(DivElement user in this.userslist.querySelectorAll(".useritem"))//remove current userlist
        {
          user.remove();
        }
          for (final users in channel.guild.members.values) //put users into list
          {
            userlist.add(users);
          }
          userlist.forEach((user) { //add users from object list to display list
          this.adduser(user);
        });
        }
        selectedChannel = channel;

        List<discord.Message> list = new List<discord.Message>();

        for (final msg in messages.values)
        {
          list.add(msg);
        }

        list.sort((a, b) {
          return a.timestamp.compareTo(b.timestamp);
        });

        list.forEach((msg) {
          this.addMessage(msg);
        });
      });
    });
  }


  adduser(discord.Member user) {
    DocumentFragment userFragment = document.importNode(userTemplate.content, true);
    ImageElement avatar = userFragment.querySelector(".offline");
    HtmlElement username = userFragment.querySelector(".user-list-name");
  if(user.avatar == null)
    {
      avatar.src = "images/iconless.png";
    }
    else
    {
      // TODO: Request webp if user agent supports it.
      avatar.src = user.avatarURL(format: 'png', size: 128);
    }
    username.title = user.id;
    username.text = user.username;
    if (user.status==null){
      avatar.className="offline";
      }
      else{
        avatar.className=user.status;
      }
    
    userslist.append(userFragment);
  }

  addMessage(discord.Message msg) {
    DocumentFragment msgFragment = document.importNode(messageTemplate.content, true);
    ImageElement avatar = msgFragment.querySelector(".user-avatar");
    HtmlElement username = msgFragment.querySelector(".user-name");
    DivElement content = msgFragment.querySelector(".content");
    if(msg.author.avatar == null)
    {
      avatar.src = "images/iconless.png";
    }
    else
    {
      // TODO: Request webp if user agent supports it.
      avatar.src = msg.author.avatarURL(format: 'png', size: 128);
    }
    username.title = msg.author.id;
    username.text = msg.author.username;
    content.innerHtml = markdownToHtml(msg.content);
    content.title = msg.id;
    if(!this.nodeValidator.allowsElement(content))
    {
      msgFragment.querySelector(".message").style.backgroundColor = "red";
      content.text = "<<Remote code execution protection has prevented this message from being displayed>>";
    }
    messages.append(msgFragment);
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
