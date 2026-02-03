import * as Turbo from '@hotwired/turbo';
import TurboPower from 'turbo_power';
import { registerDialogStreamAction } from './dialog-stream-action';
import { addTurboEventListeners } from './turbo-event-listeners';
import { registerFlashStreamAction } from './flash-stream-action';
import { registerLiveRegionStreamAction } from './live-region-stream-action';
import { registerInputCaptionStreamAction } from './input-caption-stream-action';
import { addTurboGlobalListeners } from './turbo-global-listeners';
import { applyTurboNavigationPatch } from './turbo-navigation-patch';
import { debugLog, whenDebugging } from 'core-app/shared/helpers/debug_output';
import { TURBO_EVENTS } from './constants';
import { StreamActions } from '@hotwired/turbo';
import { addTurboAngularWrapper } from 'core-turbo/turbo-angular-wrapper';

Turbo.session.drive = true;
Turbo.config.drive.progressBarDelay = 100;

// Start turbo
Turbo.start();

// Register logging of events
whenDebugging(() => {
  TURBO_EVENTS
    .filter((name) => name !== 'turbo:before-stream-render')
    .forEach((name:string) => {
    document.addEventListener(name, (event) => {
      debugLog(`[TURBO EVENT ${name}] %O`, event);
    });
  });

  document.addEventListener('turbo:before-stream-render', (event) => {
    const { detail: { newStream:stream } } = event;
    debugLog(`[TURBO EVENT turbo-before-stream-render] ${stream.action.toUpperCase()} target=${stream.target} %O`, event);
  });
});

// Register our own actions
addTurboEventListeners();
addTurboGlobalListeners();
registerDialogStreamAction();
registerFlashStreamAction();
registerLiveRegionStreamAction();
registerInputCaptionStreamAction();
addTurboAngularWrapper();

StreamActions.reloadPage = function reloadPage() {
  window.location.reload();
};

// Apply navigational patch
// https://github.com/hotwired/turbo/issues/1300
applyTurboNavigationPatch();

// Register turbo power actions
TurboPower.initialize(Turbo.StreamActions);

// Error handling when "Content missing" returned
document.addEventListener('turbo:frame-missing', (event) => {
  const { detail: { response, visit } } = event;
  event.preventDefault();
  void visit(response.url, {});
});
