resource "aws_ecrpublic_repository" "bitcoin-coverage-coverage-worker" {
  provider        = aws.us_east_1
  repository_name = "bitcoin-coverage-coverage-worker"
}

resource "aws_ecrpublic_repository" "corecheck-bench-worker" {
  provider        = aws.us_east_1
  repository_name = "corecheck-bench-worker"
}

