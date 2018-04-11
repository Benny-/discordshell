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
import 'dart:math';
import './NewTabRequestEvent.dart';
import './Tab.dart';

class Tabs {
  final DivElement _tabsHeaders;
  final DivElement _tabsContents;

  final List<Tab> _tabs = new List<Tab>();
  Tab activeTab;
  final Tab _plusTab;

  final StreamController<NewTabRequestEvent> _onNewTabRequestStreamController;
  final Stream<NewTabRequestEvent> onNewTabRequest;

  Tabs._internal(DivElement tabs, this._onNewTabRequestStreamController, this.onNewTabRequest, HtmlElement emptyContent) :
        this._tabsHeaders = tabs.querySelector(".tabs-headers"),
        this._tabsContents = tabs.querySelector(".tabs-contents"),
        this._plusTab = new Tab()
  {
    assert(this._tabsHeaders != null);
    assert(this._tabsContents != null);

    this._plusTab.headerContent.title = "Add new tab";
    this._plusTab.headerContent.text = "+";
    this._plusTab.tabContent.append(emptyContent);
    this.addTab(this._plusTab, beforePlusTab: false);

    this._plusTab.onSelect.listen((e) {
      this._onNewTabRequestStreamController.add(new NewTabRequestEvent(this));
    });
  }

  factory Tabs(DivElement tabs, emptyContent)
  {
    StreamController<NewTabRequestEvent> onNewTabRequestStreamController = new StreamController<NewTabRequestEvent>.broadcast();
    Stream<NewTabRequestEvent> onNewTabRequest = onNewTabRequestStreamController.stream;

    return new Tabs._internal(tabs, onNewTabRequestStreamController, onNewTabRequest, emptyContent);
  }

  addTab(Tab tab, {beforePlusTab: true, activate: true} )
  {
    assert(!this._tabs.contains(tab));
    
    if(beforePlusTab) {
      this._tabs.insert(this._tabs.indexOf(this._plusTab), tab);
      this._tabsHeaders.insertBefore(tab.header, this._plusTab.header);
    }
    else {
      this._tabsHeaders.append(tab.header);
      this._tabs.add(tab);
    }

    this._tabsContents.append(tab.tabContent);

    if(activeTab == null) {
      this.activeTab = tab;
      this.activeTab.activate();
    } else {
      tab.deactivate();
    }

    if(activate) {
      this.activeTab.deactivate();
      this.activeTab = tab;
      this.activeTab.activate();
    }

    tab.onSelect.listen((selectEvent) {
      this.activateTab(selectEvent.tab);
    });
  }

  removeTab(Tab tab) {
    int index = this._tabs.indexOf(tab);
    assert(index >= 0);

    this._tabs.removeAt(index);
    tab.header.remove();
    tab.tabContent.remove();

    assert(!this._tabs.contains(tab));

    if(tab == this.activeTab) {
      index = min(index, this._tabs.length - 1);
      Tab newActiveTab = this._tabs[index];

      if(newActiveTab == this._plusTab) {
        if(index > 0) {
          index--;
          newActiveTab = this._tabs[index];
        }
      }

      this.activeTab.deactivate();
      this.activeTab = newActiveTab;
      this.activeTab.activate();
    }
  }

  activateTab(Tab tab)
  {
    if(this.activeTab != null)
    {
      this.activeTab.deactivate();
    }

    this.activeTab = tab;
    this.activeTab.activate();
  }

  Future<Null> destroy() async {
    await this._onNewTabRequestStreamController.close();
    return null;
  }
}
