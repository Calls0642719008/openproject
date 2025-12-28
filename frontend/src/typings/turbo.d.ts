export interface TurboElement {
  reload:() => void;
}

export interface TurboStreamElement extends HTMLElement {
  action:string;
  target:string;
}

export interface TurboBeforeStreamRenderEvent extends CustomEvent {
  detail:{
    newStream:TurboStreamElement;
    render:(stream:TurboStreamElement) => void;
  };
}
