/*
 *  OpenProject is an open source project management software.
 *  Copyright (C) the OpenProject GmbH
 *
 *  This program is free software; you can redistribute it and/or
 *  modify it under the terms of the GNU General Public License version 3.
 *
 *  OpenProject is a fork of ChiliProject, which is a fork of Redmine. The copyright follows:
 *  Copyright (C) 2006-2013 Jean-Philippe Lang
 *  Copyright (C) 2010-2013 the ChiliProject Team
 *
 *  This program is free software; you can redistribute it and/or
 *  modify it under the terms of the GNU General Public License
 *  as published by the Free Software Foundation; either version 2
 *  of the License, or (at your option) any later version.
 *
 *  This program is distributed in the hope that it will be useful,
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *  GNU General Public License for more details.
 *
 *  You should have received a copy of the GNU General Public License
 *  along with this program; if not, write to the Free Software
 *  Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.
 *
 *  See COPYRIGHT and LICENSE files for more details.
 */

import {
  ChangeDetectorRef,
  Directive,
  ElementRef,
  Inject,
  Injector,
  OnDestroy,
  OnInit,
} from '@angular/core';
import { InjectField } from 'core-app/shared/helpers/angular/inject-field.decorator';
import { TimezoneService } from 'core-app/core/datetime/timezone.service';
import {
  EditFieldComponent,
  OpEditingPortalChangesetToken,
  OpEditingPortalHandlerToken,
  OpEditingPortalSchemaToken,
} from 'core-app/shared/components/fields/edit/edit-field.component';
import { DeviceService } from 'core-app/core/browser/device.service';
import { PathHelperService } from 'core-app/core/path-helper/path-helper.service';
import { I18nService } from 'core-app/core/i18n/i18n.service';
import { ResourceChangeset } from 'core-app/shared/components/fields/changeset/resource-changeset';
import { HalResource } from 'core-app/features/hal/resources/hal-resource';
import { IFieldSchema } from 'core-app/shared/components/fields/field.base';
import { EditFieldHandler } from 'core-app/shared/components/fields/edit/editing-portal/edit-field-handler';
import { OpModalService } from 'core-app/shared/components/modal/modal.service';
import { OpWpDatePickerModalComponent } from 'core-app/shared/components/datepicker/wp-date-picker-modal/wp-date-picker.modal';

@Directive()
export abstract class DatePickerEditFieldComponent extends EditFieldComponent implements OnInit, OnDestroy {
  @InjectField() readonly timezoneService:TimezoneService;

  @InjectField() deviceService:DeviceService;

  opened = false;

  private createHandler:EventListener = this.handleSuccessfulCreate.bind(this);
  private updateHandler:EventListener = this.handleSuccessfulUpdate.bind(this);
  private cancelHandler:EventListener = this.cancel.bind(this);

  constructor(
    readonly I18n:I18nService,
    readonly elementRef:ElementRef,
    @Inject(OpEditingPortalChangesetToken) protected change:ResourceChangeset<HalResource>,
    @Inject(OpEditingPortalSchemaToken) public schema:IFieldSchema,
    @Inject(OpEditingPortalHandlerToken) readonly handler:EditFieldHandler,
    readonly cdRef:ChangeDetectorRef,
    readonly injector:Injector,
    readonly pathHelper:PathHelperService,
    readonly opModalService:OpModalService,
  ) {
    super(I18n, elementRef, change, schema, handler, cdRef, injector);
  }

  ngOnInit():void {
    super.ngOnInit();

    document.addEventListener('date-picker-modal:create', this.createHandler);
    document.addEventListener('date-picker-modal:update', this.updateHandler);
    document.addEventListener('date-picker-modal:cancel', this.cancelHandler);
  }

  ngOnDestroy():void {
    super.ngOnDestroy();

    document.removeEventListener('date-picker-modal:create', this.createHandler);
    document.removeEventListener('date-picker-modal:update', this.updateHandler);
    document.removeEventListener('date-picker-modal:cancel', this.cancelHandler);
  }

  public onInputFocused():void {
    this
      .change
      .getForm(true)
      .then(() => {
        this.showDatePickerModal();
      })
      .catch(() => {
        this.handler.deactivate(false);
      });
  }

  public showDatePickerModal():void {
    this.opModalService
      .show(
        OpWpDatePickerModalComponent,
        this.injector,
        { resource: this.resource, name: this.name, change: this.change },
      )
      .subscribe((modal) => {
        modal
          .closingEvent
          .subscribe(() => {
            if (this.opened) {
              this.onModalClosed();
            }
          });

        this.opened = true;
      });
  }

  public handleSuccessfulCreate(event:CustomEvent):void {
    const { detail: {
      duration,
      startDate,
      dueDate,
      includeNonWorkingDays,
      scheduleManually } } = event as { detail:{ duration:number, startDate:Date, dueDate:Date, includeNonWorkingDays:boolean, scheduleManually:boolean } };

    // eslint-disable-next-line @typescript-eslint/no-unsafe-member-access
    this.resource.duration = duration ? this.timezoneService.toISODuration(duration, 'days') : null;
    // debugger;
    if (this.isMilestone()) {
      // eslint-disable-next-line @typescript-eslint/no-unsafe-member-access
      this.resource.date = startDate;
    } else {
      // eslint-disable-next-line @typescript-eslint/no-unsafe-member-access
      this.resource.dueDate = dueDate;
      // eslint-disable-next-line @typescript-eslint/no-unsafe-member-access
      this.resource.startDate = startDate;
    }
    // eslint-disable-next-line @typescript-eslint/no-unsafe-member-access
    this.resource.ignoreNonWorkingDays = includeNonWorkingDays;
    // eslint-disable-next-line @typescript-eslint/no-unsafe-member-access
    this.resource.scheduleManually = scheduleManually;

    this.onModalClosed();
  }

  public handleSuccessfulUpdate():void {
    this.onModalClosed();
  }

  public onModalClosed():void {
    this.opened = false;

    if (!this.handler.inEditMode) {
      this.handler.deactivate(false);
    }
  }

  public cancel():void {}

  private isMilestone():boolean {
    return !!this.change.schema.isMilestone;
  }
}
