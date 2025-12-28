import { ChangeDetectionStrategy, Component, EventEmitter, Input, Output } from '@angular/core';
import { UntypedFormArray } from '@angular/forms';
import { I18nService } from 'core-app/core/i18n/i18n.service';
import {
  IProjectAutocompleteItem,
} from 'core-app/shared/components/autocompleter/project-autocompleter/project-autocomplete-item';
import { IAPIFilter } from 'core-app/shared/components/autocompleter/op-autocompleter/typings';
import { HalSourceLink } from 'core-app/features/hal/interfaces';

export interface NotificationSettingProjectOption {
  name:string;
  href:string;
}

@Component({
  selector: 'op-notification-setting-inline-create',
  templateUrl: './notification-setting-inline-create.component.html',
  styleUrls: ['./notification-setting-inline-create.component.sass'],
  changeDetection: ChangeDetectionStrategy.OnPush,
  standalone: false,
})
export class NotificationSettingInlineCreateComponent {
  @Input() userId:string;

  @Input() settings:UntypedFormArray;

  @Output() selected = new EventEmitter<HalSourceLink>();

  /** Active inline-create mode */
  active = false;

  text = {
    add_setting: this.I18n.t('js.notifications.settings.project_specific.add'),
    please_select: this.I18n.t('js.placeholders.selection'),
    already_selected: this.I18n.t('js.notifications.settings.project_specific.already_selected'),
  };

  public get APIFilters():IAPIFilter[] {
    return [{ name: 'visible', operator: '=', values: [this.userId] }];
  }

  constructor(
    private I18n:I18nService,
  ) { }

  selectProject($event:NotificationSettingProjectOption):void {
    this.selected.emit({ title: $event.name, href: $event.href });
    this.active = false;
  }

  public mapProjectsFn(projects:IProjectAutocompleteItem[]):IProjectAutocompleteItem[] {
    return projects.map((project) => ({
      ...project,
      disabled: !!this.settings.controls.find(
        (projectSetting) => (projectSetting.get('project')!.value as NotificationSettingProjectOption).href === project.href,
      ),
      disabledReason: this.text.already_selected,
    }));
  }
}
