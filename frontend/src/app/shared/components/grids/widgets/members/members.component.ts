import {
  ChangeDetectionStrategy,
  Component,
  Injector,
} from '@angular/core';
import { AbstractTurboWidgetComponent } from 'core-app/shared/components/grids/widgets/abstract-turbo-widget.component';
import { I18nService } from 'core-app/core/i18n/i18n.service';
import { CurrentProjectService } from 'core-app/core/current-project/current-project.service';
import { CurrentUserService } from 'core-app/core/current-user/current-user.service';

@Component({
  selector: 'op-members-widget',
  templateUrl: './members.component.html',
  changeDetection: ChangeDetectionStrategy.OnPush,
  standalone: false
})
export class WidgetMembersComponent extends AbstractTurboWidgetComponent {
  text = {
    missing_permission: this.I18n.t('js.grid.widgets.missing_permission'),
  };

  hasCapability$ = this.currentUser.hasCapabilities$('memberships/read', this.currentProject.id);
  constructor(
    protected readonly I18n:I18nService,
    protected readonly injector:Injector,
    protected readonly currentProject:CurrentProjectService,
    protected readonly currentUser:CurrentUserService,
  ) {
    super(I18n, injector);
  }

  public get projectIdentifier() {
    return this.currentProject.identifier;
  }

  override frameId = 'grids-widgets-members';
  override name = 'members';
}
