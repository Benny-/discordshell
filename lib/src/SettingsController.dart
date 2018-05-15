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
import 'dart:async';
import 'dart:html';
import './model/AppSettings.dart';
import './model/AppSettingsChangedEvent.dart';

class SettingsController {
  final AppSettings _appSettings;
  final HtmlElement _titleContainer;
  final HtmlElement _view;

  final InputElement _enableNotifications;
  final InputElement _desktopNotifications;
  final InputElement _enableOpenTabNotifications;
  final InputElement _enableMentionNotifications;
  final InputElement _enableOpenTabMentionNotifications;

  StreamSubscription<AppSettingsChangedEvent> _streamSubscription;

  SettingsController._internal(this._appSettings, this._titleContainer, this._view) :
        _enableNotifications = _view.querySelector('input[name="enableNotifications"]'),
        _desktopNotifications = _view.querySelector('input[name="desktopNotifications"]'),
        _enableOpenTabNotifications = _view.querySelector('input[name="enableOpenTabNotifications"]'),
        _enableMentionNotifications = _view.querySelector('input[name="enableMentionNotifications"]'),
        _enableOpenTabMentionNotifications = _view.querySelector('input[name="enableOpenTabMentionNotifications"]')
  {
    _titleContainer.text = "Settings";

    _streamSubscription = this._appSettings.onAppSettingsChangedEvent.listen((e) {
      this._loadSettings();
      this._disableOptionsWithUnmetDependecies();
    });

    _enableNotifications.addEventListener('change', (e) {
      this._appSettings.enableNotifications = _enableNotifications.checked;
      this._disableOptionsWithUnmetDependecies();
      this._appSettings.notifyChangeListeners();
    });

    _desktopNotifications.addEventListener('change', (e) {
      this._appSettings.desktopNotifications = _desktopNotifications.checked;
      this._appSettings.notifyChangeListeners();
    });

    _enableOpenTabNotifications.addEventListener('change', (e) {
      this._appSettings.enableOpenTabNotifications = _enableOpenTabNotifications.checked;
      this._appSettings.notifyChangeListeners();
    });

    _enableMentionNotifications.addEventListener('change', (e) {
      this._appSettings.enableMentionNotifications = _enableMentionNotifications.checked;
      this._disableOptionsWithUnmetDependecies();
      this._appSettings.notifyChangeListeners();
    });

    _enableOpenTabMentionNotifications.addEventListener('change', (e) {
      this._appSettings.enableOpenTabMentionNotifications = _enableOpenTabMentionNotifications.checked;
      this._appSettings.notifyChangeListeners();
    });

    this._loadSettings();
    this._disableOptionsWithUnmetDependecies();
  }

  factory SettingsController(
      AppSettings _appSettings,
      HtmlElement _titleContainer,
      HtmlElement _contentContainer,
      TemplateElement _template) {
    DocumentFragment fragment = document.importNode(_template.content, true);
    HtmlElement _view = fragment.querySelector('form');
    _contentContainer.append(fragment);
    return new SettingsController._internal(_appSettings, _titleContainer, _view);
  }

  _loadSettings() {
    this._enableNotifications.checked = this._appSettings.enableNotifications;
    this._desktopNotifications.checked = this._appSettings.desktopNotifications;
    this._enableOpenTabNotifications.checked = this._appSettings.enableOpenTabNotifications;
    this._enableMentionNotifications.checked = this._appSettings.enableMentionNotifications;
    this._enableOpenTabMentionNotifications.checked = this._appSettings.enableOpenTabMentionNotifications;
  }

  _disableOptionsWithUnmetDependecies() {
    this._enableNotifications.disabled = false;
    this._desktopNotifications.disabled = false;
    this._enableOpenTabNotifications.disabled = false;
    this._enableMentionNotifications.disabled = false;
    this._enableOpenTabMentionNotifications.disabled = false;

    if(!this._enableNotifications.checked) {
      this._desktopNotifications.disabled = true;
      this._enableOpenTabNotifications.disabled = true;
      this._enableMentionNotifications.disabled = true;
      this._enableOpenTabMentionNotifications.disabled = true;
    }

    if(this._enableMentionNotifications.checked) {
      this._enableOpenTabMentionNotifications.disabled = true;
    }
  }

  Future<Null> destroy() async {
    await _streamSubscription.cancel();
    return null;
  }
}