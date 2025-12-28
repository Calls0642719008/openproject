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
/* eslint-disable @typescript-eslint/no-explicit-any */

import { Application } from '@hotwired/stimulus';
import TruncationController from './truncation.controller';

const nextFrame = () => new Promise((resolve) => requestAnimationFrame(resolve));

describe('TruncationController', () => {
  let Stimulus:Application;
  let fixturesElement:HTMLElement;
  let originalI18n:any;

  beforeEach(() => {
    fixturesElement = document.createElement('div');
    document.body.appendChild(fixturesElement);

    // Save original I18n and configure translations
    // eslint-disable-next-line @typescript-eslint/no-unsafe-assignment
    originalI18n = (window as any).I18n;
    if (originalI18n && typeof originalI18n.store === 'function') {
      originalI18n.store({
        en: {
          js: {
            label_expand_text: 'Expand text',
            label_collapse_text: 'Collapse text',
          },
        },
      });
    }
  });

  beforeEach(async () => {
    Stimulus = Application.start();
    Stimulus.handleError = (error, message, detail) => {
      console.error(error, message, detail);
    };
    Stimulus.register('truncation', TruncationController);
    await nextFrame();
  });

  const truncationTemplate = `
    <div data-controller="truncation" data-truncation-expanded-value="false">
      <div data-truncation-target="truncate" style="width: 200px; overflow: hidden;">
        <span class="Truncate-text" style="display: inline-block; white-space: nowrap;">
          This is a very long text that should be truncated when it exceeds the container width
        </span>
      </div>
      <div data-truncation-target="expander">
        <button type="button">Toggle</button>
      </div>
    </div>
  `;

  function appendTemplate(html:string) {
    const template = document.createElement('template');
    template.innerHTML = html.trim();
    fixturesElement.appendChild(template.content.cloneNode(true));
  }

  describe('initialization', () => {
    beforeEach(async () => {
      appendTemplate(truncationTemplate);
      await nextFrame();
    });

    it('connects successfully', () => {
      const controller = Stimulus.getControllerForElementAndIdentifier(
        document.querySelector('[data-controller="truncation"]')!,
        'truncation',
      );

      expect(controller).toBeDefined();
    });

    it('sets initial aria attributes on expander button', () => {
      const button = document.querySelector<HTMLButtonElement>('[data-truncation-target="expander"] button')!;

      expect(button.getAttribute('aria-label')).toBe('Expand text');
      expect(button.getAttribute('aria-expanded')).toBe('false');
    });

    it('adds Truncate--expanded class when expanded value is true', async () => {
      const truncateEl = document.querySelector<HTMLElement>('[data-truncation-target="truncate"]')!;

      expect(truncateEl.classList.contains('Truncate--expanded')).toBeFalse();

      const controller:any = Stimulus.getControllerForElementAndIdentifier(
        document.querySelector('[data-controller="truncation"]')!,
        'truncation',
      );

      controller.expandedValue = true;
      await nextFrame();

      expect(truncateEl.classList.contains('Truncate--expanded')).toBeTrue();
    });
  });

  describe('expander button click', () => {
    beforeEach(async () => {
      appendTemplate(truncationTemplate);
      await nextFrame();
    });

    it('toggles expanded state', async () => {
      const button = document.querySelector<HTMLButtonElement>('[data-truncation-target="expander"] button')!;
      const truncateEl = document.querySelector<HTMLElement>('[data-truncation-target="truncate"]')!;

      expect(truncateEl.classList.contains('Truncate--expanded')).toBeFalse();
      expect(button.getAttribute('aria-expanded')).toBe('false');

      button.click();
      await nextFrame();

      expect(truncateEl.classList.contains('Truncate--expanded')).toBeTrue();
      expect(button.getAttribute('aria-expanded')).toBe('true');
      expect(button.getAttribute('aria-label')).toBe('Collapse text');

      button.click();
      await nextFrame();

      expect(truncateEl.classList.contains('Truncate--expanded')).toBeFalse();
      expect(button.getAttribute('aria-expanded')).toBe('false');
      expect(button.getAttribute('aria-label')).toBe('Expand text');
    });
  });

  describe('expandedValue changes', () => {
    beforeEach(async () => {
      appendTemplate(truncationTemplate);
      await nextFrame();
    });

    it('updates aria-label when expanded', async () => {
      const button = document.querySelector<HTMLButtonElement>('[data-truncation-target="expander"] button')!;
      const controller:any = Stimulus.getControllerForElementAndIdentifier(
        document.querySelector('[data-controller="truncation"]')!,
        'truncation',
      );

      expect(button.getAttribute('aria-label')).toBe('Expand text');

      controller.expandedValue = true;
      await nextFrame();

      expect(button.getAttribute('aria-label')).toBe('Collapse text');
    });

    it('updates aria-expanded attribute', async () => {
      const button = document.querySelector<HTMLButtonElement>('[data-truncation-target="expander"] button')!;
      const controller:any = Stimulus.getControllerForElementAndIdentifier(
        document.querySelector('[data-controller="truncation"]')!,
        'truncation',
      );

      expect(button.getAttribute('aria-expanded')).toBe('false');

      controller.expandedValue = true;
      await nextFrame();

      expect(button.getAttribute('aria-expanded')).toBe('true');
    });

    it('toggles Truncate--expanded class', async () => {
      const truncateEl = document.querySelector<HTMLElement>('[data-truncation-target="truncate"]')!;
      const controller:any = Stimulus.getControllerForElementAndIdentifier(
        document.querySelector('[data-controller="truncation"]')!,
        'truncation',
      );

      expect(truncateEl.classList.contains('Truncate--expanded')).toBeFalse();

      controller.expandedValue = true;
      await nextFrame();

      expect(truncateEl.classList.contains('Truncate--expanded')).toBeTrue();

      controller.expandedValue = false;
      await nextFrame();

      expect(truncateEl.classList.contains('Truncate--expanded')).toBeFalse();
    });
  });

  describe('expander visibility', () => {
    // Helper to wait for ResizeObserver to process updates
    const waitForResize = async () => {
      // Wait multiple frames to ensure ResizeObserver has fired
      await nextFrame();
      await nextFrame();
    };

    it('hides expander when content is not truncated', async () => {
      const shortTextTemplate = `
        <div data-controller="truncation" data-truncation-expanded-value="false">
          <div data-truncation-target="truncate" style="width: 500px; overflow: hidden;">
            <span class="Truncate-text" style="display: inline-block; white-space: nowrap;">
              Short text
            </span>
          </div>
          <div data-truncation-target="expander">
            <button type="button">Toggle</button>
          </div>
        </div>
      `;

      appendTemplate(shortTextTemplate);
      await waitForResize();

      const expander = document.querySelector<HTMLElement>('[data-truncation-target="expander"]')!;

      // When content is not truncated, expander should be hidden
      expect(expander.hidden).toBeTrue();
    });

    it('shows expander when content is truncated', async () => {
      const longTextTemplate = `
        <div data-controller="truncation" data-truncation-expanded-value="false">
          <div data-truncation-target="truncate" style="width: 50px; overflow: hidden;">
            <span class="Truncate-text" style="display: inline-block; white-space: nowrap; width: 300px;">
              This is a very long text that should definitely be truncated
            </span>
          </div>
          <div data-truncation-target="expander">
            <button type="button">Toggle</button>
          </div>
        </div>
      `;

      appendTemplate(longTextTemplate);
      await waitForResize();

      const expander = document.querySelector<HTMLElement>('[data-truncation-target="expander"]')!;

      // When content is truncated, expander should be visible
      expect(expander.hidden).toBeFalse();
    });
  });

  describe('resize() method', () => {
    it('calls update() when resize is triggered', async () => {
      const template = `
        <div data-controller="truncation" data-truncation-expanded-value="false">
          <div data-truncation-target="truncate" style="width: 100px; overflow: hidden;">
            <span class="Truncate-text" style="display: inline-block; white-space: nowrap;">
              Test text
            </span>
          </div>
          <div data-truncation-target="expander">
            <button type="button">Toggle</button>
          </div>
        </div>
      `;

      appendTemplate(template);
      await nextFrame();

      const controller:any = Stimulus.getControllerForElementAndIdentifier(
        document.querySelector('[data-controller="truncation"]')!,
        'truncation',
      );

      // Spy on the private update method to verify resize() calls it
      const updateSpy = spyOn<any>(controller, 'update').and.callThrough();

      controller.resize();

      expect(updateSpy).toHaveBeenCalledWith();
    });

    it('updates expander visibility when content dimensions change', async () => {
      const template = `
        <div data-controller="truncation" data-truncation-expanded-value="false">
          <div data-truncation-target="truncate" style="width: 100px; overflow: hidden;">
            <span class="Truncate-text" style="display: inline-block; white-space: nowrap;">
              Test
            </span>
          </div>
          <div data-truncation-target="expander">
            <button type="button">Toggle</button>
          </div>
        </div>
      `;

      appendTemplate(template);
      await nextFrame();

      const controller:any = Stimulus.getControllerForElementAndIdentifier(
        document.querySelector('[data-controller="truncation"]')!,
        'truncation',
      );
      const expander = document.querySelector<HTMLElement>('[data-truncation-target="expander"]')!;
      const truncateText = document.querySelector<HTMLElement>('.Truncate-text')!;

      // Mock scrollWidth and clientWidth to simulate truncation state
      const originalScrollWidth = Object.getOwnPropertyDescriptor(HTMLElement.prototype, 'scrollWidth');
      const originalClientWidth = Object.getOwnPropertyDescriptor(HTMLElement.prototype, 'clientWidth');

      // Simulate not truncated: scrollWidth === clientWidth
      Object.defineProperty(truncateText, 'scrollWidth', { configurable: true, value: 100 });
      Object.defineProperty(truncateText, 'clientWidth', { configurable: true, value: 100 });
      controller.resize();

      expect(expander.hidden).toBeTrue();

      // Simulate truncated: scrollWidth > clientWidth
      Object.defineProperty(truncateText, 'scrollWidth', { configurable: true, value: 200 });
      Object.defineProperty(truncateText, 'clientWidth', { configurable: true, value: 100 });
      controller.resize();

      expect(expander.hidden).toBeFalse();

      // Simulate not truncated again
      Object.defineProperty(truncateText, 'scrollWidth', { configurable: true, value: 50 });
      Object.defineProperty(truncateText, 'clientWidth', { configurable: true, value: 50 });
      controller.resize();

      expect(expander.hidden).toBeTrue();

      // Restore original descriptors
      if (originalScrollWidth) {
        Object.defineProperty(HTMLElement.prototype, 'scrollWidth', originalScrollWidth);
      }
      if (originalClientWidth) {
        Object.defineProperty(HTMLElement.prototype, 'clientWidth', originalClientWidth);
      }
    });

    it('keeps expander visible when expanded even if not truncated', async () => {
      const template = `
        <div data-controller="truncation" data-truncation-expanded-value="false">
          <div data-truncation-target="truncate" style="width: 200px; overflow: hidden;">
            <span class="Truncate-text" style="display: inline-block; white-space: nowrap;">
              Short
            </span>
          </div>
          <div data-truncation-target="expander">
            <button type="button">Toggle</button>
          </div>
        </div>
      `;

      appendTemplate(template);
      await nextFrame();

      const controller:any = Stimulus.getControllerForElementAndIdentifier(
        document.querySelector('[data-controller="truncation"]')!,
        'truncation',
      );
      const expander = document.querySelector<HTMLElement>('[data-truncation-target="expander"]')!;

      // Initially short text, expander should be hidden
      controller.resize();

      expect(expander.hidden).toBeTrue();

      // Expand the text
      controller.expandedValue = true;
      await nextFrame();

      // When expanded, expander should remain visible even if not truncated
      expect(expander.hidden).toBeFalse();
    });
  });

  afterEach(() => {
    fixturesElement.remove();
    Stimulus.stop();
    // Restore original I18n
    if (originalI18n) {
      // eslint-disable-next-line @typescript-eslint/no-unsafe-assignment
      (window as any).I18n = originalI18n;
    }
  });
});
