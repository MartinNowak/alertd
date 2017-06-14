import { AlertdPage } from './app.po';

describe('alertd App', () => {
  let page: AlertdPage;

  beforeEach(() => {
    page = new AlertdPage();
  });

  it('should display welcome message', () => {
    page.navigateTo();
    expect(page.getParagraphText()).toEqual('Welcome to app!!');
  });
});
