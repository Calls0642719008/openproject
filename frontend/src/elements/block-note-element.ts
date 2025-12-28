/*
 * -- copyright
 * OpenProject is an open source project management software.
 * Copyright (C) 2023 the OpenProject GmbH
 *
 * This program is free software; you can redistribute it and/or
 * modify it under the terms of the GNU General Public License version 3.
 *
 * OpenProject is a fork of ChiliProject, which is a fork of Redmine. The copyright follows:
 * Copyright (C) 2006-2013 Jean-Philippe Lang
 * Copyright (C) 2010-2013 the ChiliProject Team
 *
 * This program is free software; you can redistribute it and/or
 * modify it under the terms of the GNU General Public License
 * as published by the Free Software Foundation; either version 2
 * of the License, or (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.
 *
 * See COPYRIGHT and LICENSE files for more details.
 * ++
 */

import { User } from '@blocknote/core/comments';
import { HocuspocusProvider } from '@hocuspocus/provider';
import { LiveCollaborationManager } from 'core-stimulus/helpers/live-collaboration-helpers';
import { ShadowDomWrapper } from 'op-blocknote-extensions';
import React from 'react';
import type { Root } from 'react-dom/client';
import { createRoot } from 'react-dom/client';
import OpBlockNoteContainer from '../react/OpBlockNoteContainer';

class BlockNoteElement extends HTMLElement {
  private mount:HTMLDivElement;
  private errorContainer:HTMLDivElement;
  private reactRoot:Root|null = null;

  constructor() {
    super();

    const shadowRoot = this.attachShadow({ mode: 'open' });
    // Container for connection error/recovery messages (rendered by React via fetchConnectionTemplate)
    this.errorContainer = document.createElement('div');
    this.errorContainer.id = 'documents-show-edit-view-connection-error-notice-component';
    this.mount = document.createElement('div');
    shadowRoot.appendChild(this.errorContainer);
    shadowRoot.appendChild(this.mount);

    const blockNoteStylesheetUrl = this.getAttribute('blocknote-stylesheet-url');
    if (blockNoteStylesheetUrl) {
      const link = document.createElement('link');
      link.setAttribute('rel', 'stylesheet');
      link.setAttribute('href', blockNoteStylesheetUrl);
      shadowRoot.appendChild(link);
    }

    const shadowDomStylesheetUrl = this.getAttribute('shadow-dom-stylesheet-url');
    if (shadowDomStylesheetUrl) {
      const link = document.createElement('link');
      link.setAttribute('rel', 'stylesheet');
      link.setAttribute('href', shadowDomStylesheetUrl);
      shadowRoot.appendChild(link);
    }
  }

  connectedCallback() {
    this.reactRoot = createRoot(this.mount);

    const collaborationEnabled = this.getAttribute('collaboration-enabled') === 'true';

    const render = (provider?:HocuspocusProvider) => {
      this.reactRoot?.render(
        React.createElement(React.StrictMode, null, this.BlockNoteReactContainer(provider))
      );
    };

    if (collaborationEnabled) {
      LiveCollaborationManager.onReady(render);
    } else {
      render();
    }
  }

  disconnectedCallback() {
    if (this.reactRoot) {
      this.reactRoot.unmount();
      this.reactRoot = null;
    }
  }

  private BlockNoteReactContainer = (hocuspocusProvider?:HocuspocusProvider) => {
    return React.createElement(
      ShadowDomWrapper,
      { target: this.mount },
      React.createElement(
        OpBlockNoteContainer,
        {
          inputField: document.createElement('input'),
          activeUser: this.parseActiveUser()!,
          readOnly: this.getAttribute('read-only') === 'true',
          openProjectUrl: this.getAttribute('open-project-url') ?? '',
          attachmentsUploadUrl: this.getAttribute('attachments-upload-url') ?? '',
          attachmentsCollectionKey: this.getAttribute('attachments-collection-key') ?? '',
          hocuspocusProvider: hocuspocusProvider,
          errorContainer: this.errorContainer,
        }
      )
    );
  };

  private parseActiveUser():User | null {
    const userData = this.getAttribute('active-user');
    if (userData) {
      try {
        return JSON.parse(userData) as User;
      } catch (e) {
        console.error('Failed to parse active user data:', e);
        return null;
      }
    }
    return null;
  }

}

if (!customElements.get('op-block-note')) {
  customElements.define('op-block-note', BlockNoteElement);
}
