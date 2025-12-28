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

import { HocuspocusProvider } from '@hocuspocus/provider';
import { debugLog } from 'core-app/shared/helpers/debug_output';
import { useCallback, useEffect, useRef, useState } from 'react';
import * as Y from 'yjs';

function useConnectionTimeout(provider:HocuspocusProvider | undefined, timeoutMs = 5000) {
  const [hasTimedOut, setHasTimedOut] = useState(false);
  const timeoutRef = useRef<ReturnType<typeof setTimeout> | null>(null);

  useEffect(() => {
    setHasTimedOut(false);
    if (!provider) return;

    if (provider.synced) {
      setHasTimedOut(false);
      return;
    }

    timeoutRef.current = setTimeout(() => {
      if (!provider.synced) {
        setHasTimedOut(true);
      }
    }, timeoutMs);

    return () => {
      if (timeoutRef.current) {
        clearTimeout(timeoutRef.current);
        timeoutRef.current = null;
      }
    };
  }, [provider, timeoutMs]);

  return hasTimedOut;
}

function useCollaborationProvider(
  provider:HocuspocusProvider | undefined,
  onSynced:() => void,
  onDisconnect:() => void,
) {
  useEffect(() => {
    if (!provider) return;

    if (provider.synced) {
      onSynced();
    }

    provider.on('synced', onSynced);
    provider.on('disconnect', onDisconnect);

    return () => {
      provider.off('synced', onSynced);
      provider.off('disconnect', onDisconnect);
    };
  }, [provider, onSynced, onDisconnect]);
}

function useLocalDocumentSync(doc:Y.Doc, inputField:HTMLInputElement, enabled:boolean) {
  useEffect(() => {
    if (!enabled) return;

    const updateInput = () => {
      const update = Y.encodeStateAsUpdate(doc);
      const b64 = btoa(String.fromCharCode(...update));
      inputField.value = b64;
    };

    doc.on('update', updateInput);

    return () => {
      doc.off('update', updateInput);
      doc.destroy();
    };
  }, [doc, inputField, enabled]);
}

export function useCollaboration(
  provider:HocuspocusProvider | undefined,
  doc:Y.Doc,
  inputField:HTMLInputElement,
) {
  const [isLoading, setIsLoading] = useState(true);
  const [connectionError, setConnectionError] = useState(false);

  const handleSynced = useCallback(() => {
    debugLog('(BlockNote Editor) synced with collaboration server');
    setIsLoading(false);
    setConnectionError(false);
  }, []);

  const handleDisconnect = useCallback(() => {
    debugLog('(BlockNote Editor) Disconnected from collaboration server');
    setConnectionError(true);
  }, []);

  const hasTimedOut = useConnectionTimeout(provider);
  useCollaborationProvider(provider, handleSynced, handleDisconnect);
  useLocalDocumentSync(doc, inputField, !provider);

  useEffect(() => {
    if (!provider) {
      setIsLoading(false);
    }
  }, [provider]);

  useEffect(() => {
    if (hasTimedOut) {
      debugLog('(BlockNote Editor) Connection to collaboration server timed out');
      setConnectionError(true);
      setIsLoading(false);
    }
  }, [hasTimedOut]);

  return { isLoading, connectionError } as const;
}

export { useCollaborationProvider };
