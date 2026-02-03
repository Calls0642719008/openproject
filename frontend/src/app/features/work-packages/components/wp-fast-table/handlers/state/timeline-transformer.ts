import { Injector } from '@angular/core';
import { takeUntil } from 'rxjs/operators';
import { IsolatedQuerySpace } from 'core-app/features/work-packages/directives/query-space/isolated-query-space';
import { WorkPackageViewTimelineService } from 'core-app/features/work-packages/routing/wp-view-base/view-services/wp-view-timeline.service';
import { WorkPackageTimelineState } from 'core-app/features/work-packages/routing/wp-view-base/view-services/wp-table-timeline';
import { InjectField } from 'core-app/shared/helpers/angular/inject-field.decorator';
import { WorkPackageTable } from '../../wp-fast-table';

export class TimelineTransformer {
  @InjectField() public querySpace:IsolatedQuerySpace;

  @InjectField() public wpTableTimeline:WorkPackageViewTimelineService;

  constructor(readonly injector:Injector,
    readonly table:WorkPackageTable) {
    this.wpTableTimeline
      .live$()
      .pipe(
        takeUntil(this.querySpace.stopAllSubscriptions),
      )
      .subscribe((state:WorkPackageTimelineState) => {
        this.renderVisibility(state.visible);
      });
  }

  /**
   * Update all currently visible rows to match the selection state.
   */
  private renderVisibility(visible:boolean) {
    const container = this.table.tableAndTimelineContainer.parentElement!;
    container.querySelectorAll('.work-packages-tabletimeline--timeline-side, .work-packages-tabletimeline--table-side')
      .forEach((sideEl) => sideEl.classList.toggle('-timeline-visible', visible));
  }
}
