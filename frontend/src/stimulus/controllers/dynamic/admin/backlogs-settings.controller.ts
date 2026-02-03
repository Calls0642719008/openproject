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
import { type SelectPanelElement, type SelectPanelItem } from '@openproject/primer-view-components/app/components/primer/alpha/select_panel_element';
import { type ItemActivatedEvent } from '@openproject/primer-view-components/app/components/primer/shared_events';

/**
 * Stimulus Controller adding behavior to Admin > Backlogs page.
 */
export default class BacklogsSettings extends Controller<HTMLElement> {
  static targets = ['storyTypes', 'taskType'];

  declare readonly storyTypesTarget:SelectPanelElement;
  declare readonly taskTypeTarget:SelectPanelElement;
  declare readonly hasStoryTypesTarget:boolean;
  declare readonly hasTaskTypeTarget:boolean;

  private originalLabel?:string;

  storyTypesTargetConnected(target:SelectPanelElement) {
    target.addEventListener('itemActivated', this.onStoryTypesActivated);

    // this can be removed once implemented upstream: https://github.com/primer/view_components/pull/3825
    this.setDynamicLabel(this.storyTypesTarget);
  }

  storyTypesTargetDisconnected(target:SelectPanelElement) {
    target.removeEventListener('itemActivated', this.onStoryTypesActivated);
  }

  taskTypeTargetConnected(target:SelectPanelElement) {
    target.addEventListener('itemActivated', this.onTaskTypeActivated);
  }

  taskTypeTargetDisconnected(target:SelectPanelElement) {
    target.removeEventListener('itemActivated', this.onTaskTypeActivated);
  }

  private onStoryTypesActivated = (_event:CustomEvent<ItemActivatedEvent>) => {
    if (!this.hasTaskTypeTarget) return;
    this.syncSelectPanels(this.storyTypesTarget, this.taskTypeTarget);

    // this can be removed once implemented upstream: https://github.com/primer/view_components/pull/3825
    this.setDynamicLabel(this.storyTypesTarget);
  };

  private onTaskTypeActivated = (_event:CustomEvent<ItemActivatedEvent>) => {
    if (!this.hasStoryTypesTarget) return;
    this.syncSelectPanels(this.taskTypeTarget, this.storyTypesTarget);
  };

  /**
   * Syncs two select panels - ensuring selections are mutually exclusive.
   *
   * @param source source select panel
   * @param target target select panel
   */
  private syncSelectPanels(source:SelectPanelElement, target:SelectPanelElement) {
    const sourceSelectedValues = new Set(
      source.selectedItems
        .map((item) => item.value)
        .filter((value):value is string => value != null && value !== '')
    );

    target.items.forEach((targetItem:SelectPanelItem) => {
      const itemContent = targetItem.querySelector<HTMLElement>('.ActionListContent');
      const itemValue   = itemContent?.dataset.value;
      if (!itemValue) return;

      if (sourceSelectedValues.has(itemValue)) {
        target.disableItem(targetItem);
        target.uncheckItem(targetItem);
      } else {
        target.enableItem(targetItem);
      }
    });
  }

  // this can be removed once implemented upstream: https://github.com/primer/view_components/pull/3825
  private setDynamicLabel(panel:SelectPanelElement) {
    const invokerLabel = panel.invokerLabel!;
    this.originalLabel ??= invokerLabel.textContent ?? '';
    const selectedLabels = Array.from(panel.querySelectorAll(`[${panel.ariaSelectionType}=true] .ActionListItem-label`))
        .map((label) => label.textContent?.trim() ?? '')
        .join(', ');

    if (selectedLabels) {
      const prefixSpan = document.createElement('span');
      prefixSpan.classList.add('color-fg-muted');
      const contentSpan = document.createElement('span');
      prefixSpan.textContent = `${panel.dynamicLabelPrefix} `;
      contentSpan.textContent = selectedLabels;
      invokerLabel.replaceChildren(prefixSpan, contentSpan);

      if (panel.dynamicAriaLabelPrefix) {
        panel.invokerElement?.setAttribute('aria-label', `${panel.dynamicAriaLabelPrefix} ${selectedLabels}`);
      }
    } else {
      invokerLabel.textContent = this.originalLabel;
    }
  }
}

