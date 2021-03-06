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
import 'package:json_annotation/json_annotation.dart';
import '../events/AppSettingsChangedEvent.dart';
import 'dart:async';

part 'AppSettings.g.dart';

@JsonSerializable(nullable: false)
class AppSettings {

  bool enableNotifications = true;
  bool desktopNotifications = false;
  bool enableOpenTabNotifications = true;
  bool enableOpenTabMentionNotifications = false;
  bool enableMentionNotifications = true;

  final StreamController<AppSettingsChangedEvent> _onAppSettingsChangedEventStreamController;
  final Stream<AppSettingsChangedEvent> onAppSettingsChangedEvent;

  AppSettings._internal(this._onAppSettingsChangedEventStreamController, this.onAppSettingsChangedEvent) {

  }

  factory AppSettings () {

    StreamController<AppSettingsChangedEvent> streamController = new StreamController<AppSettingsChangedEvent>.broadcast();
    Stream<AppSettingsChangedEvent> stream = streamController.stream;

    return new AppSettings._internal(streamController, stream);
  }

  factory AppSettings.fromJson(Map<String, dynamic> json) => _$AppSettingsFromJson(json);

  Map<String, dynamic> toJson() => _$AppSettingsToJson(this);

  notifyChangeListeners() {
    return this._onAppSettingsChangedEventStreamController.add(new AppSettingsChangedEvent(this));
  }

  Future<Null> destroy() async {
    await this._onAppSettingsChangedEventStreamController.close();
    return null;
  }
}
