import { ComponentFixture, fakeAsync, TestBed, tick } from '@angular/core/testing';
import { States } from 'core-app/core/states/states.service';
import { provideHttpClientTesting } from '@angular/common/http/testing';
import { NO_ERRORS_SCHEMA } from '@angular/core';
import { of, map } from 'rxjs';
import { NgSelectModule } from '@ng-select/ng-select';

import { OpAutocompleterComponent } from './op-autocompleter.component';
import { TOpAutocompleterResource } from './typings';
import { By } from '@angular/platform-browser';
import { provideHttpClient, withInterceptorsFromDi } from '@angular/common/http';

describe('autocompleter', () => {
  let fixture:ComponentFixture<OpAutocompleterComponent>;
  let getOptionsFnSpy:jasmine.Spy;
  const workPackagesStub = [
    {
      id: 1,
      subject: 'Workpackage 1',
      name: 'Workpackage 1',
      author: {
        href: '/api/v3/users/1',
        name: 'Author1',
      },
      description: {
        format: 'markdown',
        raw: 'Description of WP1',
        html: '<p>Description of WP1</p>',
      },
      createdAt: '2021-03-26T10:42:14Z',
      updatedAt: '2021-03-26T10:42:14Z',
      dueDate: '2021-03-26T10:42:14Z',
      startDate: '2021-03-26T10:42:14Z',
    },
    {
      id: 2,
      subject: 'Workpackage 2',
      name: 'Workpackage 2',
      author: {
        href: '/api/v3/users/2',
        name: 'Author2',
      },
      description: {
        format: 'markdown',
        raw: 'Description of WP2',
        html: '<p>Description of WP2</p>',
      },
      createdAt: '2021-03-26T10:42:14Z',
      updatedAt: '2021-03-26T10:42:14Z',
      dueDate: '2021-03-26T10:42:14Z',
      startDate: '2021-03-26T10:42:14Z',
    },
  ];

  beforeEach(() => {
    TestBed.configureTestingModule({
    declarations: [OpAutocompleterComponent],
    schemas: [NO_ERRORS_SCHEMA],
    imports: [NgSelectModule],
    providers: [States, provideHttpClient(withInterceptorsFromDi()), provideHttpClientTesting()]
}).compileComponents();

    fixture = TestBed.createComponent(OpAutocompleterComponent);
    getOptionsFnSpy = jasmine.createSpy('getOptionsFn').and.callFake((searchTerm:string) => {
      return of(workPackagesStub).pipe(
        map((wps) => wps.filter((wp) => searchTerm !== '' && wp.subject.includes(searchTerm)))
      );
    });

    fixture.componentInstance.resource = 'work_packages' as TOpAutocompleterResource;
    fixture.componentInstance.filters = [];
    fixture.componentInstance.searchKey = 'subjectOrId';
    fixture.componentInstance.appendTo = 'body';
    fixture.componentInstance.multiple = false;
    fixture.componentInstance.closeOnSelect = true;
    fixture.componentInstance.virtualScroll = true;
    fixture.componentInstance.classes = 'wp-relations-autocomplete';
    fixture.componentInstance.getOptionsFn = getOptionsFnSpy;
    fixture.componentInstance.debounceTimeMs = 0;
  });

  it('should load the ng-select correctly', fakeAsync(() => {
    fixture.detectChanges();
    tick();

    const autocompleter = document.querySelector('.ng-select-container');

    expect(document.contains(autocompleter)).toBeTruthy();
  }));

  describe('without debounce', () => {
    it('should load items', fakeAsync(() => {
      tick();
      fixture.detectChanges();
      fixture.componentInstance.ngAfterViewInit();
      tick(1000);
      fixture.detectChanges();
      const select = fixture.componentInstance.ngSelectInstance;

      expect(select.isOpen).toBeFalse();
      select.open();
      select.focus();

      expect(select.isOpen).toBeTrue();

      expect(select.itemsList.items.length).toEqual(0);

      const inputDebugElement = fixture.debugElement.query(By.css('input[role=combobox]'));
      const inputElement = inputDebugElement.nativeElement as HTMLInputElement;

      fixture.detectChanges();
      tick();

      expect(getOptionsFnSpy).toHaveBeenCalledWith('');

      inputElement.value = 'Wor';
      inputElement.dispatchEvent(new Event('input'));
      fixture.detectChanges();
      tick();

      expect(getOptionsFnSpy).toHaveBeenCalledWith('Wor');

      fixture.detectChanges();

      expect(select.itemsList.items.length).toEqual(2);

      inputElement.value = 'package 2';
      inputElement.dispatchEvent(new Event('input'));
      fixture.detectChanges();
      tick();

      expect(getOptionsFnSpy).toHaveBeenCalledWith('package 2');

      fixture.detectChanges();

      expect(select.itemsList.items.length).toEqual(1);
    }));
  });

  describe('with debounce', () => {
    beforeEach(() => {
      fixture.componentInstance.debounceTimeMs = 50;
    });

    it('should load items with debounce', fakeAsync(() => {
      tick();
      fixture.detectChanges();
      fixture.componentInstance.ngAfterViewInit();
      tick(1000);
      fixture.detectChanges();
      const select = fixture.componentInstance.ngSelectInstance;

      expect(select.isOpen).toBeFalse();
      select.open();
      select.focus();

      expect(select.isOpen).toBeTrue();

      expect(select.itemsList.items.length).toEqual(0);

      const inputDebugElement = fixture.debugElement.query(By.css('input[role=combobox]'));
      const inputElement = inputDebugElement.nativeElement as HTMLInputElement;

      fixture.detectChanges();

      expect(getOptionsFnSpy).toHaveBeenCalledWith('');
      getOptionsFnSpy.calls.reset();

      inputElement.value = 'Wor';
      inputElement.dispatchEvent(new Event('input'));
      fixture.detectChanges();
      tick();

      expect(getOptionsFnSpy).not.toHaveBeenCalled();
      tick(50);

      expect(getOptionsFnSpy).toHaveBeenCalledWith('Wor');
    }));
  });
});
