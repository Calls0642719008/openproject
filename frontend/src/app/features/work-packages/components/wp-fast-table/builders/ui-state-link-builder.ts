import { StateService } from '@uirouter/core';
import { KeepTabService } from 'core-app/features/work-packages/components/wp-single-view-tabs/keep-tab/keep-tab.service';
import { CurrentProjectService } from 'core-app/core/current-project/current-project.service';
import { PathHelperService } from 'core-app/core/path-helper/path-helper.service';
import { InjectField } from 'core-app/shared/helpers/angular/inject-field.decorator';

export const uiStateLinkClass = '__ui-state-link';
export const checkedClassName = '-checked';

export class UiStateLinkBuilder {
  constructor(
    public readonly $state:StateService,
    public readonly keepTab:KeepTabService,
    public readonly currentProject:CurrentProjectService,
    public readonly pathHelper:PathHelperService,
  ) {
  }

  public linkToDetails(workPackageId:string, title:string, content:string) {
    return this.build(workPackageId, 'split', title, content);
  }

  public linkToShow(workPackageId:string, title:string, content:string) {
    return this.build(workPackageId, 'show', title, content);
  }

  private build(workPackageId:string, state:'show'|'split', title:string, content:string) {
    const a = document.createElement('a');
    let tabState:string;
    let tabIdentifier:string;
    let href:string;

    if (state === 'show') {
      const projectIdentifier = this.currentProject.identifier;
      href = this.pathHelper.genericWorkPackagePath(projectIdentifier, workPackageId, this.keepTab.currentShowTab) + window.location.search;
    } else {
      const tab = this.keepTab.currentDetailsTab;
      href = this.$state.href(
        'work-packages.partitioned.list.details.tabs',
        {
          workPackageId,
          tab,
        },
      );
    }

    a.href = href;
    a.classList.add(uiStateLinkClass);
    a.dataset.workPackageId = workPackageId;
    a.dataset.wpState = state;

    a.setAttribute('title', title);
    a.textContent = content;

    return a;
  }
}
