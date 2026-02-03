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

import { Controller } from '@hotwired/stimulus';
import * as Turbo from '@hotwired/turbo';
import { debugLog } from 'core-app/shared/helpers/debug_output';
import dragula, { Drake } from 'dragula';
import { useMeta } from 'stimulus-use';
import invariant from 'tiny-invariant';

interface TargetConfig {
  container:Element;
  allowedDragType:string|null;
  targetId:string|null;
}

export default class GenericDragAndDropController extends Controller {
  static targets = ['container'];

  containerTargets:HTMLElement[];

  static metaNames = ['csrf-token'];
  declare readonly csrfToken:string;

  static values = { handleSelector: { type: String, default: '.DragHandle' } };
  declare readonly handleSelectorValue:string;

  private drake:Drake|null = null;
  private containers:HTMLElement[] = [];
  private targetConfigs:TargetConfig[] = [];

  connect() {
    useMeta(this, { suffix: false });

    this.drake?.destroy();
    this.initDrake();
  }

  disconnect() {
    this.drake?.destroy();
    this.drake = null;
  }

  containerTargetConnected(target:HTMLElement) {
    const container = this.resolveContainerElement(target);
    const targetConfig:TargetConfig = {
      container,
      allowedDragType: target.getAttribute('data-target-allowed-drag-type'),
      targetId: target.getAttribute('data-target-id'),
    };

    // we need to save the targetConfigs separately as we need to pass the pure container elements to drake
    // but need the configuration of the targets when dropping elements
    this.targetConfigs.push(targetConfig);
    this.containers.push(container);
  }

  containerTargetDisconnected(target:HTMLElement) {
    const container = this.resolveContainerElement(target);
    const index = this.containers.indexOf(container);
    if (index !== -1) {
      this.containers.splice(index, 1);
      this.targetConfigs.splice(index, 1);
    }
  }

  cancel() {
    this.drake?.cancel(true);
  }

  initDrake() {
    // Note: dragula stores a reference to this.containers, so mutations
    // from containerTargetConnected/Disconnected automatically propagate
    this.drake = dragula(
      this.containers,
      {
        moves: (_el, _source, handle, _sibling) => !!handle && !!handle.closest(this.handleSelectorValue),
        accepts: (el:Element, target:Element, source:Element, sibling:Element) => this.accepts(el, target, source, sibling),
        revertOnSpill: true, // enable reverting of elements if they are dropped outside of a valid target
      },
    )
      .on('drag', (el) => {
        const handle = el.querySelector(this.handleSelectorValue)!;
        handle.setAttribute('aria-pressed', 'true');
      })
      .on('dragend', (el) => {
        const handle = el.querySelector(this.handleSelectorValue)!;
        handle.setAttribute('aria-pressed', 'false');
       })
      // eslint-disable-next-line @typescript-eslint/no-misused-promises
      .on('drop', this.drop.bind(this));

    // Setup autoscroll
    void window.OpenProject.getPluginContext().then((pluginContext) => {
      new pluginContext.classes.DomAutoscrollService(
        [
          document.getElementById('content-body')!,
        ],
        {
          margin: 25,
          maxSpeed: 10,
          scrollWhenOutside: true,
          autoScroll: () => this.drake?.dragging,
        },
      );
    });
  }

  accepts(el:Element, target:Element, _source:Element|null, _sibling:Element|null) {
    const targetConfig = this.targetConfigs.find((config) => config.container === target);
    const acceptedDragType = targetConfig?.allowedDragType as string|undefined;

    const draggableType = el.getAttribute('data-draggable-type');

    if (draggableType !== acceptedDragType) {
      debugLog('Element is not allowed to be dropped here');
      return false;
    }

    return true;
  }

  async drop(el:Element, target:Element, _source:Element|null, _sibling:Element|null) {
    const dropUrl = el.getAttribute('data-drop-url');
    const data = this.buildData(el, target);

    if (dropUrl) {
      const response = await fetch(dropUrl, {
        method: 'PUT',
        body: data,
        headers: {
          'X-CSRF-Token': this.csrfToken,
          Accept: 'text/vnd.turbo-stream.html',
        },
        credentials: 'same-origin',
      });

      if (!response.ok) {
        debugLog('Failed to sort item');
      } else {
        const text = await response.text();
        Turbo.renderStreamMessage(text);
      }
    }

    this.cancel();
  }

  protected buildData(el:Element, target:Element):FormData {
    let targetPosition = Array.from(target.children).indexOf(el);
    if (target.children.length > 0 && target.children[0].getAttribute('data-empty-list-item') === 'true') {
      // if the target container is empty, a list item showing an empty message might be shown
      // this should not be counted as a list item
      // thus we need to subtract 1 from the target position
      targetPosition -= 1;
    }

    const data = new FormData();

    data.append('position', (targetPosition + 1).toString());

    const targetConfig = this.targetConfigs.find((config) => config.container === target);
    const targetId = targetConfig?.targetId as string|undefined;

    if (targetId) {
      data.append('target_id', targetId.toString());
    }

    return data;
  }

  // if the target has a container accessor, use that as the container instead of the element itself
  // we need this e.g. in Primer's borderbox component as we cannot add required data attributes to the ul element there
  private resolveContainerElement(target:HTMLElement):HTMLElement {
    const accessor = target.getAttribute('data-target-container-accessor');
    if (!accessor) {
      return target;
    }
    const container = target.querySelector<HTMLElement>(accessor);
    invariant(container, `Expected container element matching "${accessor}"`);
    return container;
  }
}
