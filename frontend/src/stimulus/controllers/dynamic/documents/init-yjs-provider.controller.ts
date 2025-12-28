/*
 * -- copyright
 * openproject is an open source project management software.
 * copyright (c) the openproject gmbh
 *
 * this program is free software; you can redistribute it and/or
 * modify it under the terms of the gnu general public license version 3.
 *
 * openproject is a fork of chiliproject, which is a fork of redmine. the copyright follows:
 * copyright (c) 2006-2013 jean-philippe lang
 * copyright (c) 2010-2013 the chiliproject team
 *
 * this program is free software; you can redistribute it and/or
 * modify it under the terms of the gnu general public license
 * as published by the free software foundation; either version 2
 * of the license, or (at your option) any later version.
 *
 * this program is distributed in the hope that it will be useful,
 * but without any warranty; without even the implied warranty of
 * merchantability or fitness for a particular purpose.  see the
 * gnu general public license for more details.
 *
 * you should have received a copy of the gnu general public license
 * along with this program; if not, write to the free software
 * foundation, inc., 51 franklin street, fifth floor, boston, ma  02110-1301, usa.
 *
 * see copyright and license files for more details.
 * ++
 */

import { HocuspocusProvider } from '@hocuspocus/provider';
import { Controller } from '@hotwired/stimulus';
import { LiveCollaborationManager } from 'core-stimulus/helpers/live-collaboration-helpers';
import type { Doc } from 'yjs';
import * as Y from 'yjs';

export default class extends Controller {
  static values = {
    hocuspocusUrl: String,
    oauthToken: String,
    documentName: String,
  };

  declare readonly hocuspocusUrlValue:string;
  declare readonly oauthTokenValue:string;
  declare readonly documentNameValue:string;

  connect():void {
    const ydoc:Doc = new Y.Doc();
    const provider = new HocuspocusProvider({
      url: this.hocuspocusUrlValue,
      name: this.documentNameValue,
      token: this.oauthTokenValue,
      document: ydoc,
    });

    LiveCollaborationManager.initializeYjsProvider(provider, ydoc);
  }

  disconnect():void {
    LiveCollaborationManager.destroy();
  }
}
