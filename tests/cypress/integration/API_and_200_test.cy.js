describe('Lambda API Gateway Smoke Test', () => {
  it('Returns an updated visitor count and updates the database', () => {
    cy.request('GET', 'https://wpl4v1vlpj.execute-api.us-east-1.amazonaws.com/prod/lambdaddb').then((response) => {
      const initialCount = parseInt(response.body, 10);
      expect(response.status).to.eq(200);
      
      cy.request('POST', 'https://wpl4v1vlpj.execute-api.us-east-1.amazonaws.com/prod/lambdaddb').then(() => {
        cy.request('GET', 'https://wpl4v1vlpj.execute-api.us-east-1.amazonaws.com/prod/lambdaddb').then((response) => {
          const updatedCount = parseInt(response.body, 10);
          expect(response.status).to.eq(200);
          expect(updatedCount).to.eq(initialCount + 1);
        });
      });
    });
  });
});