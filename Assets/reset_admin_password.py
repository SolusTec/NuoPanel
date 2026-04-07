from django.core.management.base import BaseCommand
from django.contrib.auth import get_user_model
from django.db import connection


class Command(BaseCommand):
    help = 'Resets or creates the Panel admin user with whm=1 (Root/WHM superuser).'

    def add_arguments(self, parser):
        parser.add_argument('new_password', type=str, help='The new password for the admin user')

    def handle(self, *args, **kwargs):
        new_password = kwargs['new_password']
        User = get_user_model()

        try:
            # Try to get existing admin
            admin = User.objects.filter(username='admin').first()
            
            if admin:
                # Update existing user
                admin.set_password(new_password)
                admin.is_superuser = True
                admin.is_staff = True
                admin.save()
                
                # Update whm field via raw SQL (campo extra não presente no model padrão)
                with connection.cursor() as cursor:
                    cursor.execute("UPDATE auth_user SET whm = 1 WHERE username = 'admin'")
                
                self.stdout.write(self.style.SUCCESS('✅ Admin password updated successfully!'))
            else:
                # Create new admin user
                admin = User.objects.create_user(
                    username='admin',
                    email='admin@localhost',
                    password=new_password,
                    is_superuser=True,
                    is_staff=True
                )
                
                # Set whm field via raw SQL (campo extra não presente no model padrão)
                with connection.cursor() as cursor:
                    cursor.execute("UPDATE auth_user SET whm = 1 WHERE username = 'admin'")
                
                self.stdout.write(self.style.SUCCESS('✅ Admin user created successfully!'))
                
        except Exception as e:
            self.stderr.write(self.style.ERROR(f"❌ Error: {e}"))
