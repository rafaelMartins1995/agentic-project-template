# Publicar e reutilizar o template

## GitHub

1. Publique estes arquivos em um repositório.
2. Em **Settings**, habilite **Template repository**.
3. Em cada novo projeto, use **Use this template**.
4. Clone o novo repositório e execute o comando de inicialização do seu sistema.

Repositórios criados a partir de um template recebem uma história independente da origem.

Documentação oficial: [Creating a template repository](https://docs.github.com/en/repositories/creating-and-managing-repositories/creating-a-template-repository).

## Azure DevOps

1. Mantenha uma origem Git acessível com este template.
2. Em **Repos > Files**, selecione **Import repository**.
3. Informe a URL de clone da origem e o nome do novo repositório.
4. Depois da importação, clone o novo repositório e execute o comando de inicialização do seu sistema.

A importação copia o repositório e sua história. Confirme permissões e a branch padrão antes de disponibilizá-lo ao time.

Documentação oficial: [Import a Git repository to a project](https://learn.microsoft.com/en-us/azure/devops/repos/git/import-git-repository?view=azure-devops).

## Antes de compartilhar

- Escolha e adicione uma licença adequada.
- Proteja a branch principal.
- Configure os revisores e aprovações exigidos pela organização.
- Não inclua credenciais, arquivos locais ou dados de um projeto anterior.
- Faça uma execução piloto da entrevista em um repositório descartável.
