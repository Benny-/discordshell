# Discord bot shell

A pure web application to control discord bots. See what they see and chat as a bot.

#### Requirements

- [dart-sdk 2](https://webdev.dartlang.org/tools/sdk).
- [discord bot token](https://github.com/reactiflux/discord-irc/wiki/Creating-a-discord-bot-&-getting-a-token).

#### Dependencies

Execute the following commands in the project directory.

```sh
pub get
pub run build_runner build # This will create some generated dart code
```

#### Run development server

```sh
webdev serve
```

#### Build production

```sh
webdev build
```

Place build `./build` files on a webserver and navigate to the page. No other server side scipts like php required.

#### License

[BSD 3](https://opensource.org/licenses/BSD-3-Clause)
