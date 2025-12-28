import { Component, ViewEncapsulation } from '@angular/core';
import { GRID_PROVIDERS } from 'core-app/shared/components/grids/grid/grid.component';
import { GridPageComponent } from 'core-app/shared/components/grids/grid/page/grid-page.component';

@Component({
  templateUrl: '../../shared/components/grids/grid/page/grid-page.component.html',
  styleUrls: ['../../shared/components/grids/grid/page/grid-page.component.sass'],
  providers: GRID_PROVIDERS,
  encapsulation: ViewEncapsulation.None,
  standalone: false,
})
export class MyPageComponent extends GridPageComponent {
  protected gridScopePath():string {
    return this.pathHelper.myPagePath();
  }
}
