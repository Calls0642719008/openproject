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

import { ApplicationController } from 'stimulus-use';
import { TurboRequestsService } from 'core-app/core/turbo/turbo-requests.service';
import { PathHelperService } from 'core-app/core/path-helper/path-helper.service';

export default class CustomFieldRoleAssignmentController extends ApplicationController {
  static values = {
    initialRole: Number,
    customFieldId: Number
  };

  static targets = [
    'previewHintBox',
  ];

  private currentRoleValue:number;
  private customFieldIdValue:number;

  declare readonly initialRoleValue:number;
  declare readonly previewHintBoxTarget:HTMLDivElement;
  declare readonly hasPreviewHintBoxTarget:boolean;

  protected turboRequests:TurboRequestsService;
  protected pathHelper:PathHelperService;

  async connect() {
    const context = await window.OpenProject.getPluginContext();
    this.turboRequests = context.services.turboRequests;
    this.pathHelper = context.services.pathHelperService;
  }

  changeRole(event:Event):void {
    if (!this.hasPreviewHintBoxTarget) { return; }

    const selectElement = event.target as HTMLSelectElement;
    this.currentRoleValue = Number(selectElement.value);

    this.previewHintBoxTarget.classList.toggle('d-none', this.currentRoleValue === this.initialRoleValue);
  }

  showPreviewModal():void {
    void this
      .turboRequests
      .request(
        this.pathHelper.previewCustomFieldRoleAssignmentDialog(this.customFieldIdValue, this.currentRoleValue),
        {
          headers: {
            Accept: 'text/vnd.turbo-stream.html',
          },
        },
      );
  }
}
