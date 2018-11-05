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
import './events/SelectEvent.dart';
import './events/CloseEvent.dart';

class Tab {

  /**
   * Should only be used by {Tabs} class
   */
  final DivElement header;
  final bool _closable;
  final ButtonElement _closeButton;

  final DivElement headerContent;
  final DivElement tabContent;

  final StreamController<SelectEvent> _onSelectStreamController;
  final Stream<SelectEvent> onSelect;

  // ignore: conflicting_dart_import
  final StreamController<CloseEvent> _onCloseStreamController;
  final Stream<CloseEvent> onClose;

  Tab._internal(this._onSelectStreamController, this.onSelect, this._onCloseStreamController, this.onClose, this._closable)
      : this.header = new DivElement(),
        this.headerContent = new DivElement(),
        this.tabContent = new DivElement(),
        this._closeButton = new ButtonElement()
  {
    this.tabContent.className = "tab-content";
    this.deactivate();

    this.header.append(this.headerContent);

    this._closeButton.text = "❌";
    this._closeButton.className = "close-button";
    if(this._closable) {
      this.header.append(this._closeButton);
    }

    this._closeButton.addEventListener('click', (e) {
      this._onCloseStreamController.add(new CloseEvent(this));
    });

    this.headerContent.addEventListener('click', (e) {
      this._onSelectStreamController.add(new SelectEvent(this));
    });
  }

  factory Tab({bool closable = false})
  {
    StreamController<SelectEvent> onSelectStreamController = new StreamController<SelectEvent>.broadcast();
    Stream<SelectEvent> onSelect = onSelectStreamController.stream;

    StreamController<CloseEvent> onCloseStreamController = new StreamController<CloseEvent>.broadcast();
    Stream<CloseEvent> onClose = onCloseStreamController.stream;

    return new Tab._internal(onSelectStreamController, onSelect, onCloseStreamController, onClose, closable);
  }

  /**
   * Should only be used by {Tabs} class
   */
  activate()
  {
    header.className = "selected-tab-header";
    tabContent.style.display = "";
  }

  /**
   * Should only be used by {Tabs} class
   */
  deactivate()
  {
    header.className = "deselected-tab-header";
    tabContent.style.display = "none";
  }

  Future<Null> destroy() async {
    await this._onSelectStreamController.close();
    await this._onCloseStreamController.close();
    return null;
  }
}
