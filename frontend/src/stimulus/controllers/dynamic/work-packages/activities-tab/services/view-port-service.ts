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

export interface ViewPortServiceInterface {
  isMobile():boolean;
  isWithinNotificationCenter():boolean;
  isWithinSplitScreen():boolean;
  isJournalsContainerScrolledToBottom():boolean;
  scrollableContainer:HTMLElement | null;
}

export class ViewPortService implements ViewPortServiceInterface {
  private notificationCenterPathName:string;
  private splitScreenPathName:string;

  private mobileBreakpoint:number;
  private mobileBreakpointInNotificationCenter:number;

  constructor(
    notificationCenterPathName = 'notifications',
    splitScreenPathName = 'work_packages/details',
    mobileBreakpoint = 1279,
    mobileBreakpointInNotificationCenter = 1013,
  ) {
    this.notificationCenterPathName = notificationCenterPathName;
    this.splitScreenPathName = splitScreenPathName;
    this.mobileBreakpoint = mobileBreakpoint;
    this.mobileBreakpointInNotificationCenter = mobileBreakpointInNotificationCenter;
  }

  isMobile():boolean {
    if (this.isWithinNotificationCenter() || this.isWithinSplitScreen()) {
      return window.innerWidth < this.mobileBreakpointInNotificationCenter;
    }
    return window.innerWidth < this.mobileBreakpoint;
  }

  isWithinNotificationCenter():boolean {
    return window.location.pathname.includes(this.notificationCenterPathName);
  }

  isWithinSplitScreen():boolean {
    return window.location.pathname.includes(this.splitScreenPathName);
  }

  isJournalsContainerScrolledToBottom():boolean {
    let atBottom = false;
    // we have to handle different scrollable containers for different viewports/pages in order to idenfity if the user is at the bottom of the journals
    // DOM structure different for notification center and workpackage detail view as well
    const scrollableContainer = this.scrollableContainer;
    if (scrollableContainer) {
      atBottom = (scrollableContainer.scrollTop + scrollableContainer.clientHeight + 10) >= scrollableContainer.scrollHeight;
    }

    return atBottom;
  }

  get scrollableContainer():HTMLElement | null {
    if (this.isWithinNotificationCenter() || this.isWithinSplitScreen()) {
      // valid for both mobile and desktop
      return document.querySelector('.work-package-details-tab')!;
    }
    if (this.isMobile()) {
      return document.querySelector('#content-body')!;
    }

    // valid for desktop
    return document.querySelector('.tabcontent')!;
  }
}
