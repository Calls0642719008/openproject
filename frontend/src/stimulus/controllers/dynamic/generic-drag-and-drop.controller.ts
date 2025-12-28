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

import * as Turbo from '@hotwired/turbo';
import { Controller } from '@hotwired/stimulus';
import dragula, { Drake } from 'dragula';
import { debugLog } from 'core-app/shared/helpers/debug_output';
import { useMeta } from 'stimulus-use';

interface TargetConfig {
  container:Element;
  allowedDragType:string|null;
  targetId:string|null;
}

export default class GenericDragAndDropController extends Controller {
  static metaNames = ['csrf-token'];
  declare readonly csrfToken:string;

  drake:Drake|undefined;
  targetConfigs:TargetConfig[];

  containerTargets:Element[];

  observer:MutationObserver|null = null;

  connect() {
    useMeta(this, { suffix: false });
    this.initDrake();
    this.startMutationObserver();
  }

  initDrake() {
    this.setContainerTargetsAndConfigs();

    // reinit drake if it already exists
    if (this.drake) {
      this.drake.destroy();
    }

    this.drake = dragula(
      this.containerTargets,
      {
        moves: (_el, _source, handle, _sibling) => !!handle?.classList.contains('octicon-grabber'),
        accepts: (el:Element, target:Element, source:Element, sibling:Element) => this.accepts(el, target, source, sibling),
        revertOnSpill: true, // enable reverting of elements if they are dropped outside of a valid target
      },
    )
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

  reInitDrakeContainers() {
    this.setContainerTargetsAndConfigs();
    if (this.drake) {
      this.drake.containers = this.containerTargets;
    }
  }

  setContainerTargetsAndConfigs():void {
    const rawTargets = Array.from(
      this.element.querySelectorAll('[data-is-drag-and-drop-target="true"]'),
    );
    this.targetConfigs = [];
    let processedTargets:Element[] = [];

    rawTargets.forEach((target:Element) => {
      const targetConfig:TargetConfig = {
        container: target,
        allowedDragType: target.getAttribute('data-target-allowed-drag-type'),
        targetId: target.getAttribute('data-target-id'),
      };

      // if the target has a container accessor, use that as the container instead of the element itself
      // we need this e.g. in Primer's borderbox component as we cannot add required data attributes to the ul element there
      const containerAccessor = target.getAttribute('data-target-container-accessor');

      if (containerAccessor) {
        target = target.querySelector(containerAccessor)!;
        targetConfig.container = target;
      }

      // we need to save the targetConfigs separately as we need to pass the pure container elements to drake
      // but need the configuration of the targets when dropping elements
      this.targetConfigs.push(targetConfig);

      processedTargets = processedTargets.concat(target);
    });

    this.containerTargets = processedTargets;
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

    if (this.drake) {
      this.drake.cancel(true); // necessary to prevent "copying" behaviour
    }
  }

  disconnect() {
    if (this.drake) {
      this.drake.destroy();
    }

    this.stopMutationObserver();
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

  private startMutationObserver() {
    this.observer = new MutationObserver((mutations) => {
      const addedNodes = mutations
        .filter((mutation:MutationRecord) => mutation.type === 'childList')
        .map((mutation:MutationRecord) => Array.from(mutation.addedNodes))
        .reduce((acc, val) => acc.concat(val), []);

      const newTarget = addedNodes.some((node) =>
        node instanceof Element
        && node.matches('[data-is-drag-and-drop-target="true"], [data-is-drag-and-drop-target="true"] *'));

      if (newTarget) {
        this.reInitDrakeContainers();
      }
    });

    this.observer.observe(this.element, {
      childList: true,
      subtree: true,
    });
  }

  private stopMutationObserver() {
    if (this.observer) {
      this.observer.disconnect();
      this.observer = null;
    }
  }
}
