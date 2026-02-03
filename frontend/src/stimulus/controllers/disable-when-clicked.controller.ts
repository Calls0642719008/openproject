import { Controller } from '@hotwired/stimulus';

export default class DisableWhenClickedController extends Controller<HTMLInputElement> {
  static values = {
    text: String,
  };

  declare textValue:string;
  private clickListener = this.toggleDisabled.bind(this);

  connect() {
    super.connect();
    this.element.addEventListener('click', this.clickListener);
  }

  disconnect() {
    this.element.removeEventListener('click', this.clickListener);
  }

  private toggleDisabled():void {
    setTimeout(() => {
      this.element.disabled = true;

      if (this.textValue) {
        this.element.textContent = this.textValue;
      }
    });
  }
}
