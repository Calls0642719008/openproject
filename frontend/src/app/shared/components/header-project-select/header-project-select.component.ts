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

import { PathHelperService } from 'core-app/core/path-helper/path-helper.service';
import { I18nService } from 'core-app/core/i18n/i18n.service';
import { ChangeDetectionStrategy, Component, HostBinding, OnDestroy, OnInit, ViewEncapsulation } from '@angular/core';
import { CurrentProjectService } from 'core-app/core/current-project/current-project.service';
import { BehaviorSubject, Observable, ReplaySubject, Subscription } from 'rxjs';
import { map, shareReplay, take, tap } from 'rxjs/operators';
import { IProject } from 'core-app/core/state/projects/project.model';
import { insertInList } from 'core-app/shared/components/project-include/insert-in-list';
import { recursiveSort } from 'core-app/shared/components/project-include/recursive-sort';
import {
  SearchableProjectListService,
} from 'core-app/shared/components/searchable-project-list/searchable-project-list.service';
import { CurrentUserService } from 'core-app/core/current-user/current-user.service';
import { UntilDestroyedMixin } from 'core-app/shared/helpers/angular/until-destroyed.mixin';
import { IProjectData } from 'core-app/shared/components/searchable-project-list/project-data';
import { ApiV3Service } from 'core-app/core/apiv3/api-v3.service';
import { ConfigurationService } from 'core-app/core/config/configuration.service';

@Component({
  selector: 'opce-header-project-select',
  templateUrl: './header-project-select.component.html',
  styleUrls: ['./header-project-select.component.sass'],
  encapsulation: ViewEncapsulation.None,
  changeDetection: ChangeDetectionStrategy.OnPush,
  providers: [
    SearchableProjectListService,
  ],
  standalone: false,
})
export class OpHeaderProjectSelectComponent extends UntilDestroyedMixin implements OnInit, OnDestroy {
  @HostBinding('class.op-project-select') className = true;

  public dropModalOpen = false;

  public textFieldFocused = false;

  public portfolioModelsEnabled = this.configuration.activeFeatureFlags.includes('portfolioModels');

  public canCreateNewProjects$ = this.currentUserService.hasCapabilities$('projects/create', 'global');

  public projects$ = this.searchableProjectListService.allProjects$.pipe(
    map(
      (projects:IProject[]) => projects
        .filter(
          (project) => {
            const searchText = this.searchableProjectListService.searchText;
            if (searchText.length) {
              const matches = project.name.toLowerCase().includes(searchText.toLowerCase());

              if (!matches) {
                return false;
              }
            }

            return true;
          },
        )
        .sort((a, b) => a._links.ancestors.length - b._links.ancestors.length)
        .reduce(
          (list, project) => {
            const { ancestors } = project._links;

            return insertInList(
              projects,
              project,
              list,
              ancestors,
            );
          },
          [] as IProjectData[],
        ),
    ),
    map((projects) => recursiveSort(projects)),
    tap(() => {
      if(this.dropModalOpen) {
        // only clear loading indicator if modal is open, otherwise rendering is triggered that will cause loading of
        // favorites while the modal is closed
        this.loading$.next(false);
      }
    }),
    shareReplay(),
  );

  public favorites$:Observable<string[]> = this.searchableProjectListService.favoriteIds$;

  public text = {
    all: this.I18n.t('js.label_all_uppercase'),
    favorited: this.I18n.t('js.label_favorites'),
    no_favorites: this.I18n.t('js.favorite_projects.no_results'),
    no_favorites_subtext: this.I18n.t('js.favorite_projects.no_results_subtext'),
    project: {
      singular: this.I18n.t('js.label_project'),
      plural: this.I18n.t('js.label_project_plural'),
      list: this.I18n.t('js.label_project_list'),
      select: this.I18n.t('js.label_all_projects'),
      search_placeholder: this.I18n.t('js.include_projects.search_placeholder')
    },
    workspace: {
      list: this.I18n.t('js.label_workspace_list'),
      search_placeholder: this.I18n.t('js.include_workspaces.search_placeholder')
    },
    search_favorites_placeholder: this.I18n.t('js.include_projects.search_placeholder_favorites'),
    no_results: this.I18n.t('js.include_projects.no_results'),
    no_favorite_results: this.I18n.t('js.include_projects.no_favorite_results')
  };

  // Computed text properties based on portfolio models feature flag
  public get currentText() {
    return this.portfolioModelsEnabled ? this.text.workspace : this.text.project;
  }

  public displayMode:'all'|'favorited';

  public displayModeOptions = [
    { value: 'all', title: this.text.all },
    { value: 'favorited', title: this.text.favorited },
  ];

  public loading$ = new BehaviorSubject<boolean>(true);

  private scrollToCurrent = false;

  private subscriptionComplete$ = new ReplaySubject<void>(1);

  private displayModeLocalStorageKey = 'openProject-project-select-display-mode';

  constructor(
    readonly pathHelper:PathHelperService,
    readonly configuration:ConfigurationService,
    readonly I18n:I18nService,
    readonly currentProject:CurrentProjectService,
    readonly searchableProjectListService:SearchableProjectListService,
    readonly currentUserService:CurrentUserService,
    readonly apiV3Service:ApiV3Service,
  ) {
    super();

    if(this.currentProject.id) {
      this.searchableProjectListService.preloadProjectIds = [this.currentProject.id];
    }

    this.projects$
      .pipe(this.untilDestroyed())
      .subscribe((projects) => {
        if (this.currentProject.id && projects.length && this.scrollToCurrent) {
          this.searchableProjectListService.selectedItemID$.next(parseInt(this.currentProject.id, 10));
        } else {
          this.searchableProjectListService.resetActiveResult(projects);
        }

        this.scrollToCurrent = false;
        this.subscriptionComplete$.next(); // Signal that subscription logic is complete
      });
  }

  private onTextInput:Subscription;

  ngOnInit():void {
    const stored = window.OpenProject.guardedLocalStorage(this.displayModeLocalStorageKey) as 'all'|'favorited'|undefined;
    this.displayMode = stored ?? 'all';
    this.onTextInput = this.searchableProjectListService.queriedSearchText$.subscribe(() => this.loading$.next(true));
  }

  ngOnDestroy():void {
    this.onTextInput.unsubscribe();
  }

  toggleDropModal():void {
    this.subscriptionComplete$.pipe(take(1)).subscribe(() => {
      this.dropModalOpen = !this.dropModalOpen;
      if (this.dropModalOpen) {
        this.loading$.next(true);
        this.searchableProjectListService.enableLoading();
        this.scrollToCurrent = true;
      } else {
        this.searchableProjectListService.disableLoading();
      }
    });
  }

  displayModeChange(mode:'all'|'favorited'):void {
    this.displayMode = mode;
    window.OpenProject.guardedLocalStorage(this.displayModeLocalStorageKey, mode);

    if (this.currentProject.id) {
      this.searchableProjectListService.selectedItemID$.next(parseInt(this.currentProject.id, 10));
    }
  }

  close():void {
    this.dropModalOpen = false;
    this.searchableProjectListService.disableLoading();
    this.searchableProjectListService.searchText = '';
  }

  currentProjectName():string {
    if (this.currentProject.name !== null) {
      return this.currentProject.name;
    }

    return this.text.project.select;
  }

  allProjectsPath():string {
    return this.pathHelper.projectsPath();
  }

  newProjectPath():string {
    const parentParam = this.currentProject.id ? `?parent_id=${this.currentProject.id}` : '';
    return `${this.pathHelper.projectsNewPath()}${parentParam}`;
  }

  anyProjectsFound(projects:IProjectData[], favorites:string[]):boolean {
    if (this.displayMode === 'all') {
      return projects.length > 0;
    }

    return projects.length > 0 && favorites.length > 0;
  }

  searchPlaceHolder():string {
    if (this.displayMode === 'all') {
      return this.currentText.search_placeholder;
    }
    return this.text.search_favorites_placeholder;
  }

  noSearchResultsText():string {
    if (this.displayMode === 'all') {
      return this.text.no_results;
    }
    return this.text.no_favorite_results;
  }
}
