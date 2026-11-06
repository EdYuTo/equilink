-- De onde veio o resultado de uma prova, como "HorseSport". Vazio nas cadastradas à mão.
alter table provas add column if not exists fonte text;
