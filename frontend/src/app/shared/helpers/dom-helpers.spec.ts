//-- copyright
// OpenProject is an open source project management software.
// Copyright (C) the OpenProject GmbH
//
// This program is free software; you can redistribute it and/or
// modify it under the terms of the GNU General Public License version 3.
//
// OpenProject is a fork of ChiliProject, which is a fork of Redmine. The copyright follows:
// Copyright (C) 2006-2013 Jean-Philippe Lang
// Copyright (C) 2010-2013 the ChiliProject Team
//
// This program is free software; you can redistribute it and/or
// modify it under the terms of the GNU General Public License
// as published by the Free Software Foundation; either version 2
// of the License, or (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with this program; if not, write to the Free Software
// Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.
//
// See COPYRIGHT and LICENSE files for more details.
//++

import {
  toggleElement,
  toggleElementByClass,
  toggleElementByVisibility,
  attributeTokenList,
} from './dom-helpers';

describe('dom-helpers', () => {
  describe('toggleElement', () => {
    let element:HTMLElement;

    beforeEach(() => {
      element = document.createElement('div');
    });

    it('toggles the hidden property when no value is provided', () => {
      expect(element.hidden).toBe(false);
      toggleElement(element);

      expect(element.hidden).toBe(true);
      toggleElement(element);

      expect(element.hidden).toBe(false);
    });

    it('shows the element when value is true', () => {
      element.hidden = true;
      toggleElement(element, true);

      expect(element.hidden).toBe(false);
    });

    it('hides the element when value is false', () => {
      element.hidden = false;
      toggleElement(element, false);

      expect(element.hidden).toBe(true);
    });

    it('keeps element visible when value is true and element is already visible', () => {
      element.hidden = false;
      toggleElement(element, true);

      expect(element.hidden).toBe(false);
    });

    it('keeps element hidden when value is false and element is already hidden', () => {
      element.hidden = true;
      toggleElement(element, false);

      expect(element.hidden).toBe(true);
    });
  });

  describe('toggleElementByClass', () => {
    let element:Element;
    const className = 'hidden';

    beforeEach(() => {
      element = document.createElement('div');
    });

    it('toggles the CSS class and sets aria-hidden when no value is provided', () => {
      expect(element.classList.contains(className)).toBe(false);
      expect(element.getAttribute('aria-hidden')).toBeNull();

      toggleElementByClass(element, className);

      expect(element.classList.contains(className)).toBe(true);
      expect(element.getAttribute('aria-hidden')).toBe('true');

      toggleElementByClass(element, className);

      expect(element.classList.contains(className)).toBe(false);
      expect(element.getAttribute('aria-hidden')).toBe('false');
    });

    it('removes the CSS class and sets aria-hidden to false when value is true', () => {
      element.classList.add(className);
      toggleElementByClass(element, className, true);

      expect(element.classList.contains(className)).toBe(false);
      expect(element.getAttribute('aria-hidden')).toBe('false');
    });

    it('adds the CSS class and sets aria-hidden to true when value is false', () => {
      toggleElementByClass(element, className, false);

      expect(element.classList.contains(className)).toBe(true);
      expect(element.getAttribute('aria-hidden')).toBe('true');
    });

    it('keeps element visible with aria-hidden false when value is true and element is already visible', () => {
      element.classList.remove(className);
      toggleElementByClass(element, className, true);

      expect(element.classList.contains(className)).toBe(false);
      expect(element.getAttribute('aria-hidden')).toBe('false');
    });

    it('keeps element hidden with aria-hidden true when value is false and element is already hidden', () => {
      element.classList.add(className);
      toggleElementByClass(element, className, false);

      expect(element.classList.contains(className)).toBe(true);
      expect(element.getAttribute('aria-hidden')).toBe('true');
    });
  });

  describe('toggleElementByVisibility', () => {
    let element:HTMLElement;

    beforeEach(() => {
      element = document.createElement('div');
    });

    it('toggles visibility style property when no value is provided', () => {
      // Initially, visibility is not set (defaults to visible in browsers)
      expect(element.style.getPropertyValue('visibility')).toBe('');

      // First call: empty string is not 'visible', so it sets to 'visible'
      toggleElementByVisibility(element);

      expect(element.style.getPropertyValue('visibility')).toBe('visible');

      // Second call: 'visible' toggles to 'hidden'
      toggleElementByVisibility(element);

      expect(element.style.getPropertyValue('visibility')).toBe('hidden');
    });

    it('sets visibility to visible when value is true', () => {
      element.style.setProperty('visibility', 'hidden');
      toggleElementByVisibility(element, true);

      expect(element.style.getPropertyValue('visibility')).toBe('visible');
    });

    it('sets visibility to hidden when value is false', () => {
      element.style.setProperty('visibility', 'visible');
      toggleElementByVisibility(element, false);

      expect(element.style.getPropertyValue('visibility')).toBe('hidden');
    });

    it('keeps visibility visible when value is true and element is already visible', () => {
      element.style.setProperty('visibility', 'visible');
      toggleElementByVisibility(element, true);

      expect(element.style.getPropertyValue('visibility')).toBe('visible');
    });

    it('keeps visibility hidden when value is false and element is already hidden', () => {
      element.style.setProperty('visibility', 'hidden');
      toggleElementByVisibility(element, false);

      expect(element.style.getPropertyValue('visibility')).toBe('hidden');
    });
  });

  describe('attributeTokenList', () => {
    let el:HTMLElement;
    const attr = 'aria-describedby';

    beforeEach(() => {
      el = document.createElement('div');
    });

    it('mimics DOMTokenList over an attribute', () => {
      const list = attributeTokenList(el, attr);

      expect(list.contains('a')).toBeFalse();
      expect(el.getAttribute(attr)).toBeNull();

      list.add('a', 'b');

      expect(list.contains('a')).toBeTrue();
      expect(list.contains('b')).toBeTrue();
      expect(el.getAttribute(attr)).toBe('a b');

      // adding duplicates is idempotent
      list.add('a');

      expect(el.getAttribute(attr)).toBe('a b');

      // remove works
      list.remove('a');

      expect(list.contains('a')).toBeFalse();
      expect(el.getAttribute(attr)).toBe('b');

      // toggle without force flips presence and returns the new state
      expect(list.toggle('b')).toBeFalse(); // removed
      expect(el.getAttribute(attr)).toBe('');
      expect(list.toggle('c')).toBeTrue(); // added
      expect(el.getAttribute(attr)).toBe('c');

      // forced toggle honors force
      expect(list.toggle('x', true)).toBeTrue();
      expect(list.contains('x')).toBeTrue();
      expect(list.toggle('x', false)).toBeFalse();
      expect(list.contains('x')).toBeFalse();

      // replace swaps tokens and returns true when old exists
      expect(list.replace('c', 'd')).toBeTrue();
      expect(list.contains('c')).toBeFalse();
      expect(list.contains('d')).toBeTrue();

      // iterator yields tokens
      expect([...list]).toEqual(['d']);

      // value accessor updates attribute
      list.value = 'e f';

      expect(el.getAttribute(attr)).toBe('e f');
      expect(list.contains('e')).toBeTrue();
      expect(list.contains('f')).toBeTrue();
    });

    it('replace on non-existent token returns false and does not change tokens', () => {
      const list = attributeTokenList(el, attr);
      list.add('a', 'b');

      expect(list.replace('x', 'y')).toBeFalse();
      expect([...list]).toEqual(['a', 'b']);
      expect(el.getAttribute(attr)).toBe('a b');
    });

    it('iterates empty list and value setter overwrites tokens', () => {
      const list = attributeTokenList(el, attr);

      // Initially empty
      expect([...list]).toEqual([]);

      // Setting value directly replaces tokens
      list.value = 'm   n  ';

      expect([...list]).toEqual(['m', 'n']);
      expect(el.getAttribute(attr)).toBe('m n');
    });

    it('supports item() method to access tokens by index', () => {
      const list = attributeTokenList(el, attr);
      list.add('hint-1', 'hint-2', 'hint-3');

      expect(list.item(0)).toBe('hint-1');
      expect(list.item(1)).toBe('hint-2');
      expect(list.item(2)).toBe('hint-3');
      expect(list.item(5)).toBeNull();
      expect(list.item(-1)).toBeNull();
    });

    it('supports length property to get token count', () => {
      const list = attributeTokenList(el, attr);

      expect(list.length).toBe(0);

      list.add('a');

      expect(list.length).toBe(1);

      list.add('b', 'c');

      expect(list.length).toBe(3);

      list.remove('b');

      expect(list.length).toBe(2);

      list.toggle('d');

      expect(list.length).toBe(3);

      list.remove('a', 'c', 'd');

      expect(list.length).toBe(0);
    });

    it('item() reflects changes after add/remove', () => {
      el.setAttribute(attr, 'initial-1 initial-2');
      const list = attributeTokenList(el, attr);

      expect(list.item(0)).toBe('initial-1');
      expect(list.item(1)).toBe('initial-2');
      expect(list.length).toBe(2);

      list.remove('initial-1');

      expect(list.item(0)).toBe('initial-2');
      expect(list.item(1)).toBeNull();
      expect(list.length).toBe(1);
    });

    it('allows iteration by index using length', () => {
      el.setAttribute(attr, 'alpha beta gamma');
      const list = attributeTokenList(el, attr);

      const tokens:string[] = [];
      for (let i = 0; i < list.length; i++) {
        const token = list.item(i);
        if (token) tokens.push(token);
      }

      expect(tokens).toEqual(['alpha', 'beta', 'gamma']);
    });
  });
});
