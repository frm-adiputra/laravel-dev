FROM frma/baseimage-composer

# create user
RUN groupadd --gid {{GID}} -r devuser \
 && useradd --uid {{UID}} --create-home --home /home/devuser --system --gid devuser devuser \
 && usermod -aG www-data devuser

# install laravel installer
RUN composer global require "laravel/installer" \
 && mv /root/.composer /home/devuser/.composer \
 && chown -R devuser:devuser /home/devuser/.composer

# modify apache conf and php-fpm conf
RUN sed -i "s/User www-data/User devuser/" /etc/apache2/apache2.conf \
 && sed -i "s/Group www-data/Group devuser/" /etc/apache2/apache2.conf \
 && sed -i "s/Listen 80/Listen 8080/" /etc/apache2/apache2.conf \
 && sed -i "s~Mutex file:/var/lock/apache2 default~Mutex file:/home/devuser/lock/apache2 default~" /etc/apache2/apache2.conf \
 && sed -i "s~PidFile /var/run/apache2/apache2.pid~PidFile /home/devuser/apache2.pid~" /etc/apache2/apache2.conf

RUN rm -rf /var/www/html \
 && ln -s /home/devuser/src/{{PROJECT}}/public /var/www/html

# RUN docker-php-ext-configure mysql --with-mysql=mysqlnd \
# && docker-php-ext-install \
#  mysql
#
# Install PDO-MySQL PHP extension
RUN docker-php-ext-configure pdo_mysql --with-pdo-mysql=mysqlnd \
 && docker-php-ext-install \
  pdo_mysql

# RUN docker-php-ext-install pdo_mysql
# RUN php -r "print_r(php_ini_loaded_file());" \
#  && php -r "print_r(get_loaded_extensions());" \
#  && ls -l /usr/local/lib/php/extensions/no-debug-non-zts-20131226/

USER devuser
RUN mkdir -p /home/devuser/lock/apache2
ENV PATH="/home/devuser/.composer/vendor/bin:$PATH"
