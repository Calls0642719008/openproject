/*
 * -- copyright
 * OpenProject is an open source project management software.
 * Copyright (C) the OpenProject GmbH
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
import { useEffect, useRef } from 'react';
import * as Y from 'yjs';
import { DocumentLoadingSkeleton } from './components/DocumentLoadingSkeleton';
import { OpBlockNoteEditor } from './components/OpBlockNoteEditor';
import { fetchConnectionTemplate } from './helpers/connection-template-fetcher';
import { useCollaboration } from './hooks/useCollaboration';

export interface OpBlockNoteContainerProps {
  inputField:HTMLInputElement;
  inputText?:string;
  activeUser:User;
  readOnly:boolean;
  openProjectUrl:string;
  attachmentsUploadUrl:string;
  attachmentsCollectionKey:string;
  hocuspocusProvider?:HocuspocusProvider;
  errorContainer?:HTMLElement;
}

export default function OpBlockNoteContainer({ inputField,
                                               inputText,
                                               activeUser,
                                               readOnly,
                                               openProjectUrl,
                                               attachmentsUploadUrl,
                                               attachmentsCollectionKey,
                                               hocuspocusProvider,
                                               errorContainer }:OpBlockNoteContainerProps) {
  const doc:Y.Doc = hocuspocusProvider
    ? hocuspocusProvider.document
    : (() => {
      // NOTE: This should only be used in TEST environments where there is no provider.
      const newDoc = new Y.Doc();
      if (inputText) {
        try {
          const update = Uint8Array.from(atob(inputText), c => c.charCodeAt(0));
          Y.applyUpdate(newDoc, update);
        } catch (e) {
          console.error('Failed to load document binary', e);
          return new Y.Doc();
        }
      }
      return newDoc;
    })();

  const { isLoading, connectionError } = useCollaboration(hocuspocusProvider, doc, inputField);
  const hadErrorRef = useRef(false);

  // Fetch error/recovery template based on connection state
  useEffect(() => {
    if (!errorContainer) return;

    if (connectionError) {
      hadErrorRef.current = true;
      void fetchConnectionTemplate('error', errorContainer);
    } else if (hadErrorRef.current) {
      // Only fetch recovery if we previously had an error (avoid fetching on initial render)
      void fetchConnectionTemplate('recovery', errorContainer);
    }
  }, [connectionError, errorContainer]);

  if (isLoading) {
    return <DocumentLoadingSkeleton />;
  }

  if (connectionError) {
    // Error UI is rendered in errorContainer via fetchConnectionTemplate (outside React tree)
    return null;
  }

  return (
    <OpBlockNoteEditor
      activeUser={activeUser}
      readOnly={readOnly}
      openProjectUrl={openProjectUrl}
      attachmentsUploadUrl={attachmentsUploadUrl}
      attachmentsCollectionKey={attachmentsCollectionKey}
      hocuspocusProvider={hocuspocusProvider}
      doc={doc}
    />
  );
}

