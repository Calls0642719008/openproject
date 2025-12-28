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

/**
 * Fetches connection error/recovery templates from the server.
 * Used by the BlockNote editor to display server-rendered error messages
 * when the collaboration connection fails.
 */

function getDocumentIdFromUrl():string|null {
  const match = /\/documents\/(\d+)/.exec(window.location.pathname);
  return match ? match[1] : null;
}

/**
 * Parses Turbo Stream response and extracts the template content.
 * Standard Turbo.renderStreamMessage() uses document.getElementById()
 * which can't find Shadow DOM elements, so we parse manually.
 */
function parseTurboStreamContent(html:string):string|null {
  const parser = new DOMParser();
  const doc = parser.parseFromString(html, 'text/html');
  const turboStream = doc.querySelector('turbo-stream');

  if (!turboStream) {
    console.error('No turbo-stream element found in response');
    return null;
  }

  const template = turboStream.querySelector('template');
  if (!template) {
    console.error('No template element found in turbo-stream');
    return null;
  }

  return template.innerHTML;
}

export async function fetchConnectionTemplate(
  type:'error'|'recovery',
  targetElement:HTMLElement,
):Promise<void> {
  const documentId = getDocumentIdFromUrl();
  if (!documentId) {
    console.error('Could not extract document ID from URL');
    return;
  }

  const url = `/documents/${documentId}/render_connection_${type}`;

  try {
    const response = await fetch(url, {
      method: 'GET',
      headers: { Accept: 'text/vnd.turbo-stream.html' },
    });

    if (!response.ok) {
      throw new Error(`Failed to fetch ${url}: ${response.status}`);
    }

    const html = await response.text();
    const content = parseTurboStreamContent(html);

    if (content !== null) {
      targetElement.innerHTML = content;

      // Attach reload handler to the error button (Stimulus not available in Shadow DOM)
      const reloadButton = targetElement.querySelector('#connection-error-reload-button');
      if (reloadButton) {
        reloadButton.addEventListener('click', () => window.location.reload());
      }
    }
  } catch (error) {
    console.error('Error fetching connection template:', error);
  }
}
