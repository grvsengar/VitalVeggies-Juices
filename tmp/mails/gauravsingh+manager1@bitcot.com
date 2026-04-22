Date: Tue, 21 Apr 2026 16:15:49 +0530
From: hello@vitalveggies.in
To: gauravsingh+manager1@bitcot.com
Message-ID: <69e7555dc6e18_b1f10503c3849a@bitcot-Lenovo-V15.mail>
Subject: Complete your Vital Veggies manager registration
MIME-Version: 1.0
Content-Type: multipart/alternative;
 boundary="--==_mimepart_69e7555dc4160_b1f10503c3831b";
 charset=UTF-8
Content-Transfer-Encoding: 7bit


----==_mimepart_69e7555dc4160_b1f10503c3831b
Content-Type: text/plain;
 charset=UTF-8
Content-Transfer-Encoding: 7bit

Manager Portal Invitation

Hello gaurav sengar,

Admin Control created your manager access for Vital Veggies & Juices.

Complete your registration here:
http://localhost:3000/manager/register/KHXJPWIyh-bl9HKxwi7OSa4IUeh88etS

After registration, sign in to the manager portal to handle inventory and fulfilment responsibilities.


----==_mimepart_69e7555dc4160_b1f10503c3831b
Content-Type: text/html;
 charset=UTF-8
Content-Transfer-Encoding: 7bit

<!-- BEGIN app/views/layouts/mailer.html.erb --><!DOCTYPE html>
<html>
  <head>
    <meta http-equiv="Content-Type" content="text/html; charset=utf-8">
    <style>
      /* Email styles need to be inline */
    </style>
  </head>

  <body>
    <!-- BEGIN app/views/manager_invitation_mailer/invite.html.erb --><h1>Manager Portal Invitation</h1>

<p>Hello gaurav sengar,</p>

<p>Admin Control created your manager access for Vital Veggies & Juices.</p>

<p>Click the link below to complete your registration and set your password:</p>

<p><a href="http://localhost:3000/manager/register/KHXJPWIyh-bl9HKxwi7OSa4IUeh88etS">Complete manager registration</a></p>

<p>After registration, you can sign in to the manager portal and handle inventory and fulfilment responsibilities.</p>
<!-- END app/views/manager_invitation_mailer/invite.html.erb -->
  </body>
</html>
<!-- END app/views/layouts/mailer.html.erb -->
----==_mimepart_69e7555dc4160_b1f10503c3831b--


