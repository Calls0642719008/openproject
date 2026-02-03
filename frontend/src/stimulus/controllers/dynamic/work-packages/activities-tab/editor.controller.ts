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

import {
  ICKEditorInstance,
} from 'core-app/shared/components/editor/components/ckeditor/ckeditor.types';
import { retrieveCkEditorInstance } from 'core-app/shared/helpers/ckeditor-helpers';
import type AutoScrollingController from './auto-scrolling.controller';
import BaseController from './base.controller';
import type PollingController from './polling.controller';
import type StemsController from './stems.controller';

export default class EditorController extends BaseController {
  static outlets = [
    'work-packages--activities-tab--auto-scrolling',
    'work-packages--activities-tab--polling',
    'work-packages--activities-tab--stems',
  ];

  declare readonly workPackagesActivitiesTabAutoScrollingOutlet:AutoScrollingController;
  declare readonly workPackagesActivitiesTabPollingOutlet:PollingController;
  declare readonly workPackagesActivitiesTabStemsOutlet:StemsController;
  private get autoScrollingOutlet() { return this.workPackagesActivitiesTabAutoScrollingOutlet; }
  private get pollingOutlet() { return this.workPackagesActivitiesTabPollingOutlet; }
  private get stemsOutlet() { return this.workPackagesActivitiesTabStemsOutlet; }

  static values = {
    unsavedChangesConfirmationMessage: String,
  };

  declare unsavedChangesConfirmationMessageValue:string;

  static targets = ['buttonRow', 'formRow', 'form'];
  declare readonly buttonRowTarget:HTMLInputElement;
  declare readonly formRowTarget:HTMLElement;
  declare readonly formTarget:HTMLFormElement;

  private rescuedEditorDataKey:string;
  private abortController = new AbortController();
  private ckEditorAbortController = new AbortController();

  connect() {
    super.connect();

    this.setupEventListeners();
    this.setLocalStorageKeys();
    this.populateRescuedEditorContent();
  }

  disconnect() {
    this.rescueEditorContent();
    this.removeCkEditorEventListeners();
    this.removeEventListeners();
  }

  showForm() {
    const journalsContainerAtBottom = this.isJournalsContainerScrolledToBottom();

    this.buttonRowTarget.classList.add('d-none');
    this.formRowTarget.classList.remove('d-none');
    this.indexOutlet.showJournalsContainerInput();

    this.addCkEditorEventListeners();

    if (this.isMobile()) {
      this.focusEditor(0);
    } else if (this.indexOutlet.sortingAscending && journalsContainerAtBottom) {
      // scroll to (new) bottom if sorting is ascending and journals container was already at bottom before showing the form
      this.autoScrollingOutlet.scrollJournalContainer(true);
      this.focusEditor();
    } else {
      this.focusEditor();
    }
  }

  focusEditor(timeout = 10) {
    const ckEditorInstance = this.ckEditorInstance;
    if (ckEditorInstance) {
      setTimeout(() => ckEditorInstance.editing.view.focus(), timeout);
    }
  }

  openEditorWithInitialData(quotedText:string) {
    this.showForm();
    if (this.isEditorEmpty()) {
      this.ckEditorInstance!.setData(quotedText);
    }
  }

  clearEditor() {
    this.ckEditorInstance?.setData('');
  }

  hideEditor() {
    this.clearEditor(); // remove potentially empty lines
    this.removeCkEditorEventListeners();
    this.buttonRowTarget.classList.remove('d-none');
    this.formRowTarget.classList.add('d-none');
    this.indexOutlet.hideJournalsContainerInput();

    if (this.isMobile()) {
      // wait for the keyboard to be fully down before scrolling further
      // timeout amount tested on mobile devices for best possible user experience
      this.autoScrollingOutlet.scrollInputContainerIntoView(500);
    }
  }

  closeEditor() {
    if (this.isEditorEmpty()) {
      this.closeForm();
    } else {
      const shouldClose = window.confirm(this.unsavedChangesConfirmationMessageValue);
      if (shouldClose) { this.closeForm(); }
    }
  }

  onBlurEditor() {
    if (!this.isEditorEmpty()) {
      this.adjustJournalContainerMargin();
    }
  }

  onFocusEditor() {
    this.adjustJournalContainerMargin();
  }

  private setupEventListeners() {
    const { signal } = this.abortController;

    const handlers = {
      beforeUnload: () => { void this.rescueEditorContent(); },
      turboSubmitStart: (event:Event) => { void this.handleTurboSubmitStart(event); },
      turboSubmitEnd: (event:Event) => { void this.handleTurboSubmitEnd(event); },
    };

    document.addEventListener('beforeunload', handlers.beforeUnload, { signal });

    (this.element).addEventListener('turbo:submit-start', handlers.turboSubmitStart, { signal });
    (this.element).addEventListener('turbo:submit-end', handlers.turboSubmitEnd, { signal });
  }

  private removeEventListeners() {
    this.abortController.abort();
  }

  private setLocalStorageKeys() {
    this.rescuedEditorDataKey = `work-package-${this.indexOutlet.workPackageIdValue}-rescued-editor-data-${this.indexOutlet.userIdValue}`;
  }

  private populateRescuedEditorContent() {
    const rescuedEditorContent = localStorage.getItem(this.rescuedEditorDataKey);
    if (rescuedEditorContent) {
      this.openEditorWithInitialData(rescuedEditorContent);
      localStorage.removeItem(this.rescuedEditorDataKey);
    }
  }

  private addCkEditorEventListeners() {
    const { signal } = this.ckEditorAbortController;

    const handlers = {
      onEscapeEditor: () => { void this.closeEditor(); },
      adjustMargin: () => { void this.adjustJournalContainerMargin(); },
      onBlurEditor: () => { void this.onBlurEditor(); },
      onFocusEditor: () => {
        void this.onFocusEditor();
        if (this.isMobile()) { void this.autoScrollingOutlet.scrollInputContainerIntoView(200); }
      },
    };

    const editorElement = this.ckEditorAugmentedTextarea;
    if (editorElement) {
      editorElement.addEventListener('editorEscape', handlers.onEscapeEditor, { signal });
      editorElement.addEventListener('editorKeyup', handlers.adjustMargin, { signal });
      editorElement.addEventListener('editorBlur', handlers.onBlurEditor, { signal });
      editorElement.addEventListener('editorFocus', handlers.onFocusEditor, { signal });
    }
  }

  private removeCkEditorEventListeners() {
    this.ckEditorAbortController.abort();
    // Create a new AbortController for future CKEditor events
    this.ckEditorAbortController = new AbortController();
  }

  private rescueEditorContent() {
    const data = this.ckEditorInstance?.getData({ trim: false });
    if (data) {
      localStorage.setItem(this.rescuedEditorDataKey, data);
    }
  }

  private handleTurboSubmitStart(_event:Event) {
    this.setCKEditorReadonlyMode(true);
  }

  private handleTurboSubmitEnd(event:Event) {
    const formSubmitResponse = (event as CustomEvent<{ fetchResponse:{ succeeded:boolean; response:{ headers:Headers } } }>).detail.fetchResponse;

    this.setCKEditorReadonlyMode(false);

    if (formSubmitResponse.succeeded) {
      // extract server timestamp from response headers in order to be in sync with the server
      this.pollingOutlet.setLastServerTimestampViaHeaders(formSubmitResponse.response.headers);

      if (!this.indexOutlet.hasJournalsContainerTarget) return;

      this.clearEditor();
      this.closeForm();
      this.indexOutlet.resetJournalsContainerMargins();

      setTimeout(() => {
        this.autoScrollingOutlet.performAutoScrollingOnFormSubmit();
        this.stemsOutlet.handleStemVisibility();
      }, 100);
    }
  }

  private adjustJournalContainerMargin() {
    this.indexOutlet.adjustJournalContainerMarginWith(`${this.formRowTarget.clientHeight + 29}px`);
  }

  private closeForm() {
    this.hideEditor();
    this.formTarget.reset();
    this.dispatch('onSubmit-end'); // Notify other controllers that the form has been closed
  }

  private isEditorEmpty():boolean {
    return this.ckEditorInstance?.getData({ trim: false }) === '';
  }

  private setCKEditorReadonlyMode(disabled:boolean) {
    const editorLockID = 'work-packages-activities-tab-index-component';

    if (disabled) {
      this.ckEditorInstance?.enableReadOnlyMode(editorLockID);
    } else {
      this.ckEditorInstance?.disableReadOnlyMode(editorLockID);
    }
  }

  private get ckEditorAugmentedTextarea():HTMLElement | null {
    return (this.element).querySelector('opce-ckeditor-augmented-textarea');
  }

  get ckEditorInstance():ICKEditorInstance | undefined {
    return retrieveCkEditorInstance(this.element as HTMLElement);
  }
}
