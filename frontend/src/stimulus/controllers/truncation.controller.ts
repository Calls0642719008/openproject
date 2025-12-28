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
import { useResize } from 'stimulus-use';

export default class TruncationController extends Controller<HTMLElement> {
  static targets = ['truncate', 'expander'];
  static values = { expanded: Boolean };

  declare readonly truncateTarget:HTMLElement;
  declare readonly expanderTarget:HTMLElement;
  declare expandedValue:boolean;
  declare readonly expandLabelValue:string;
  declare readonly collapseLabelValue:string;

  private abortController:AbortController|null = null;

  connect() {
    useResize(this, { element: this.truncateTarget });
    this.update();
  }

  resize() {
    this.update();
  }

  expanderTargetConnected(_target:HTMLElement) {
    this.abortController = new AbortController();
    const { signal } = this.abortController;
    this.expanderButton.addEventListener('click', () => this.expanderClicked(), { signal });
  }

  expanderTargetDisconnected(_target:HTMLElement) {
    this.abortController?.abort();
  }

  expandedValueChanged(value:boolean) {
    this.expanderButton.setAttribute('aria-label', value ? I18n.t('js.label_collapse_text') : I18n.t('js.label_expand_text'));
    this.expanderButton.setAttribute('aria-expanded', String(value));
    this.truncateTarget.classList.toggle('Truncate--expanded', value);
    this.update(); // Redundant call to ensure state consistency; the resize observer will likely trigger this anyway.
  }

  get truncateText():HTMLElement {
    return this.truncateTarget.querySelector<HTMLElement>('.Truncate-text')!;
  }

  get expanderButton():HTMLButtonElement {
    return this.expanderTarget.querySelector<HTMLButtonElement>('button')!;
  }

  private update() {
    const truncated = this.truncateText.scrollWidth > this.truncateText.clientWidth;
    this.expanderTarget.hidden = !truncated && !this.expandedValue;
  }

  private expanderClicked() {
    this.expandedValue = !this.expandedValue;
  }
}
