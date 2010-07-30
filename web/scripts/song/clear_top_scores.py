# Set up django environment
from django.core.management import setup_environ
from aptf import settings
setup_environ(settings)

from aptf.paths.models import TopScore
from django.db import transaction

if __name__ == "__main__":
  transaction.enter_transaction_management()
  transaction.managed(True)
  for top_score in TopScore.objects.all():
    top_score.delete()
  transaction.commit()
  transaction.leave_transaction_management()
