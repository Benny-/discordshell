# Discord bot shell

A pure web application to control discord bots. See what they see and chat as a bot.

#### Requirements

- [dart-sdk 2.0.0-dev.20.0](https://webdev-dartlang-org-dev.firebaseapp.com/tools/sdk/archive).
- A [discord bot token](https://github.com/reactiflux/discord-irc/wiki/Creating-a-discord-bot-&-getting-a-token).

#### Dependencies

Execute the following commands in the project directory.

```sh
git clone https://github.com/Hackzzila/nyx.git
cd "nyx"
git reset --hard "1e9e7ff5812b5b7f72694aac4bf58bcb11877f15"
```

```sh
pub get
```

#### Run Development server

```sh
pub serve
```

#### Build production

```sh
pub build
```

Place build `./dist` files on a webserver and navigate to the page. No other server side scipts like php required.

#### License

[BSD 3](https://opensource.org/licenses/BSD-3-Clause)
